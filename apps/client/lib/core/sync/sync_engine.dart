import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/session/presentation/providers/app_session_controller.dart';
import '../../features/wishes/data/wish_photo_picker.dart';
import '../../features/wishes/domain/wish.dart';
import '../database/app_database.dart';
import '../database/database_provider.dart';
import '../media/media_paths.dart';
import '../media/media_upload_service.dart';
import '../network/api_client.dart';
import '../services/preferences_service.dart';
import 'outbox_store.dart';

/// Статус синхронизации для UI/диагностики.
enum SyncStatus { idle, syncing, offline, error, unauthorized }

/// Offline-first sync engine.
///
/// Отвечает за:
///  * push — доставку outbox-операций на API (FIFO, sequential);
///  * pull — полный snapshot `GET /wishes` + reconcile в Drift.
///
/// НЕ читает данные для UI — UI всегда читает Drift.
/// Сеть здесь — только механизм синхронизации.
///
/// Жизненный цикл привязан к аккаунту через [attach]/[detach]:
/// engine никогда не отправляет операции чужого `owner_id`.
class SyncEngine {
  SyncEngine({
    required AppDatabase db,
    required this._dio,
    required this._onUnauthorized,
    required this._onStatus,
    MediaUploadService? mediaUploads,
  }) : _db = db,
       _outbox = OutboxStore(db),
       _mediaUploads = mediaUploads ?? MediaUploadService(api: _dio);

  final AppDatabase _db;
  final Dio _dio;
  final OutboxStore _outbox;
  final MediaUploadService _mediaUploads;
  final void Function() _onUnauthorized;
  final void Function(SyncStatus) _onStatus;

  /// Текущий аккаунт; `null` — engine detached, sync невозможен.
  String? _ownerId;

  bool _runAgain = false;
  bool _authExpired = false;
  Future<void>? _inflight;

  StreamSubscription<int>? _outboxSub;

  /// Привязка к аккаунту: подписка на outbox (мутации сами
  /// инициируют sync) + начальный pull.
  ///
  /// Повторный attach того же аккаунта после 401 обязан снять
  /// `_authExpired` — иначе sync навсегда остановлен даже после
  /// успешной повторной авторизации.
  void attach(String ownerId) {
    if (_ownerId == ownerId && !_authExpired) return;
    detach();
    _ownerId = ownerId;
    _authExpired = false;
    _outboxSub = _db.watchOutboxCount(ownerId).listen((count) {
      if (count > 0) unawaited(requestSync());
    });
    unawaited(requestSync());
  }

  void detach() {
    _ownerId = null;
    unawaited(_outboxSub?.cancel());
    _outboxSub = null;
  }

  /// Запросить синхронизацию. Single-flight: повторный вызов во время
  /// выполнения ставит флаг повторного прогона и возвращает тот же
  /// Future — параллельных sync не бывает, вызывающий может дождаться
  /// фактического завершения прогона.
  Future<void> requestSync() {
    if (_ownerId == null || _authExpired) return Future.value();
    _runAgain = true;
    return _inflight ??= _run();
  }

  Future<void> _run() async {
    _onStatus(SyncStatus.syncing);
    try {
      do {
        _runAgain = false;
        await _push();
        // Media upload идёт после entity push: сервер должен
        // знать желание для ownership-проверки media API.
        final ownerId = _ownerId;
        if (ownerId != null) await _pushWishMedia(ownerId);
        await _pull();
      } while (_runAgain && _ownerId != null && !_authExpired);
      _onStatus(SyncStatus.idle);
    } on _AuthExpired {
      _onStatus(SyncStatus.unauthorized);
      _onUnauthorized();
    } catch (_) {
      // Сеть недоступна/5xx/прочее — локальные данные не тронуты,
      // outbox сохранил операции; следующий trigger повторит.
      _onStatus(SyncStatus.offline);
    } finally {
      _inflight = null;
    }
  }

  // ── Push ──────────────────────────────────────────────────

  Future<void> _push() async {
    final ownerId = _ownerId;
    if (ownerId == null) return;

    final now = DateTime.now();
    final ops = await _db.dueOutbox(ownerId, now);
    for (final op in ops) {
      // Аккаунт мог смениться между операциями.
      if (_ownerId != ownerId) return;
      await _process(op);
    }
  }

  Future<void> _process(OutboxEntry op) async {
    try {
      // Позиция не может уйти на сервер раньше родительского
      // списка: пока у списка незавершённый create — child-операция
      // откладывается (остаётся pending без attempt-штрафа).
      if (await _shouldDefer(op)) return;
      switch (op.operation) {
        case OutboxOp.create:
          await _pushCreate(op);
        case OutboxOp.update:
          await _pushUpdate(op);
        case OutboxOp.delete:
          await _pushDelete(op);
      }
    } on DioException catch (e) {
      await _handleHttpError(op, e);
    } catch (e) {
      // Ответ относится к устаревшему намерению, если операция
      // была замещена/переписана, пока запрос был в полёте —
      // не штрафуем свежую операцию ошибкой старого запроса.
      final fresh = await _freshOp(op);
      if (fresh != null) await _outbox.markRetry(fresh, e.toString());
    }
  }

  /// Актуальная версия операции, если она всё ещё описывает то же
  /// намерение, что и в момент отправки запроса; `null` — операция
  /// замещена (compaction) или переписана новой мутацией (revive
  /// меняет payload) — ответ сервера тогда относится к устаревшему
  /// намерению и не должен менять состояние свежей операции.
  Future<OutboxEntry?> _freshOp(OutboxEntry op) async {
    final fresh = await _db.outboxEntryById(op.id);
    if (fresh == null || fresh.payloadJson != op.payloadJson) {
      return null;
    }
    return fresh;
  }

  /// Инвариант parent→child: операция `shopping_item` доставляется
  /// только когда родительский список уже существует на сервере
  /// (нет незавершённой create-операции списка — pending ИЛИ failed:
  /// failed-родитель означает, что сервер его не принял).
  ///
  /// FIFO-порядок outbox обычно уже гарантирует это; проверка —
  /// страховка для случаев, когда create списка отложен backoff'ом,
  /// а операция позиции due раньше.
  Future<bool> _shouldDefer(OutboxEntry op) async {
    if (op.entityType != 'shopping_item') return false;
    final listId = await _itemListId(op);
    if (listId == null) return false; // сирота — пусть получит 404
    return _outbox.hasUnsyncedCreate(op.ownerId, listId);
  }

  /// listId позиции: из payload (create) или из локальной строки
  /// (update/delete — payload родителя не хранит).
  Future<String?> _itemListId(OutboxEntry op) async {
    final fromPayload = _payload(op)['list_id'];
    if (fromPayload is String) return fromPayload;
    final row = await _db.shoppingItemByIdAny(op.ownerId, op.entityId);
    return row?.listId;
  }

  Map<String, dynamic> _payload(OutboxEntry op) =>
      jsonDecode(op.payloadJson ?? '{}') as Map<String, dynamic>;

  /// Коллекция API для entity type.
  String _collection(OutboxEntry op) => switch (op.entityType) {
    'shopping_list' => '/shopping-lists',
    'shopping_item' => '/shopping-items',
    'friendship' => '/friends',
    'profile' => '/me',
    _ => '/wishes',
  };

  /// Endpoint создания: позиция создаётся внутри родительского
  /// списка `POST /shopping-lists/{listId}/items`.
  String _createPath(OutboxEntry op) => op.entityType == 'shopping_item'
      ? '/shopping-lists/${_payload(op)['list_id']}/items'
      : _collection(op);

  Future<void> _pushCreate(OutboxEntry op) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        _createPath(op),
        data: _payload(op),
      );
      await _db.transaction(() async {
        // Ответ пришёл после detach/смены аккаунта — ничего не
        // пишем: op.ownerId может принадлежать уже вычищенной
        // записи чужого (разлогиненного) аккаунта.
        if (_ownerId != op.ownerId) return;
        // Check + apply + complete одной транзакцией: мутация
        // пользователя — отдельная транзакция, сериализуется до или
        // после и не может проскочить в окно между проверкой
        // in-flight convergence и complete (иначе complete снёс бы
        // только что записанный свежий payload — потеря намерения).
        if (await _convergeInFlightMutation(op)) return;
        await _applyServerEntity(op, res.data?['data']);
        await _outbox.complete(op.id);
        // Follow-up update расходящихся полей — той же
        // транзакцией ПОСЛЕ complete (compaction слил бы update в
        // ещё не снятый create; а вынос за транзакцию дал бы окно
        // для detach/clearAccountData → воскрешение outbox-строки
        // вычищенного аккаунта).
        await _reconcileDivergence(op, res.data?['data']);
      });
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        // Та же identity уже на сервере (lost-response retry):
        // принять серверное представление и завершить операцию.
        await _resolveConflict(op);
        return;
      }
      rethrow;
    }
  }

  /// Endpoint чтения сущности для reconcile после 409.
  /// Отдельного `GET /shopping-items/{id}` нет — позицию читаем
  /// через родительский список.
  String _readPath(OutboxEntry op) {
    if (op.entityType == 'shopping_item') {
      return '/shopping-lists/${_payload(op)['list_id'] ?? ''}';
    }
    return '${_collection(op)}/${op.entityId}';
  }

  /// Совпадает ли reconcile-ответ с отправленным payload'ом?
  /// Тогда 409 — это lost response нашего же create, и поля,
  /// которые сервер не сохранил (is_checked при POST /items),
  /// — незавершённое намерение: сохраняем и довозим отдельно.
  /// Не совпадает — identity занята чужой сущностью.
  /// Сравниваем только поля, которые сервер гарантированно
  /// сохраняет при create.
  bool _isOwnEntityEcho(OutboxEntry op, Map<String, dynamic> entity) {
    final sent = _payload(op);
    return switch (op.entityType) {
      'shopping_item' =>
        // is_checked сервер игнорирует при POST — не сравниваем.
        entity['title'] == sent['title'] &&
            (entity['quantity'] as int? ?? 1) ==
                (sent['quantity'] as int? ?? 1),
      'shopping_list' => entity['title'] == sent['title'],
      'friendship' =>
        // GET /friends/{id} → PublicUserResource {id, ...};
        // POST отправлял {user_id: friendId}.
        entity['id'] == op.entityId,
      _ =>
        entity['title'] == sent['title'] &&
            entity['description'] == sent['description'] &&
            (entity['price'] as int?) == (sent['price'] as int?) &&
            entity['link'] == sent['link'] &&
            entity['image_url'] == sent['image_url'],
    };
  }

  /// Извлечь серверное представление сущности из GET-ответа
  /// (для позиции — ищем её внутри списка).
  Map<String, dynamic>? _extractServerEntity(
    OutboxEntry op,
    Map<String, dynamic>? data,
  ) {
    if (data == null) return null;
    if (op.entityType != 'shopping_item') return data;
    final items = data['items'];
    if (items is! List) return null;
    for (final raw in items) {
      if ((raw as Map)['id'] == op.entityId) {
        return raw as Map<String, dynamic>;
      }
    }
    return null;
  }

  Future<void> _resolveConflict(OutboxEntry op) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(_readPath(op));
      final entity = _extractServerEntity(op, res.data?['data']);
      await _db.transaction(() async {
        if (_ownerId != op.ownerId) return;
        // Сначала convergence: замещённая/переписанная в полёте
        // операция означает, что и 409, и этот GET относились к
        // устаревшему намерению — drop/apply не делаем.
        if (await _convergeInFlightMutation(op)) return;
        if (entity == null) {
          // Сущность недоступна/отсутствует на сервере — убрать
          // локально вместе с операцией.
          await _dropLocalEntity(op);
          return;
        }
        // 409 при одинаковой identity — два случая:
        // - lost response: сервер хранит НАШУ сущность — эхо
        //   совпадает с отправленным payload'ом. Поля, которые
        //   сервер не сохранил (is_checked), довозим follow-up'ом.
        // - чужая сущность с тем же id: данные отличаются от
        //   отправленных → серверное представление авторитетно,
        //   без follow-up'а — локальные поля не перебиваем наверх.
        final own = _isOwnEntityEcho(op, entity);
        await _applyServerEntity(op, entity, preserveLocal: own);
        await _outbox.complete(op.id);
        if (own) await _reconcileDivergence(op, entity);
      });
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // 409 подтвердил существование, но ресурс недоступен нам
        // (чужой UUID-коллизия) — операция невыполнима. Только для
        // того намерения, что ушло в запрос: свежая мутация в полёте
        // сохраняет и сущность, и новую операцию.
        await _db.transaction(() async {
          if (_ownerId != op.ownerId) return;
          if (await _freshOp(op) == null) return;
          await _dropLocalEntity(op);
        });
        return;
      }
      rethrow;
    }
  }

  /// Endpoint обновления: профиль — `PATCH /me` без id-сегмента
  /// (identity профиля — сам аккаунт, отдельного UUID нет).
  String _updatePath(OutboxEntry op) =>
      op.entityType == 'profile' ? '/me' : '${_collection(op)}/${op.entityId}';

  Future<void> _pushUpdate(OutboxEntry op) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        _updatePath(op),
        data: _payload(op),
      );
      await _db.transaction(() async {
        if (_ownerId != op.ownerId) return;
        if (await _convergeInFlightMutation(op)) return;
        await _applyServerEntity(op, res.data?['data']);
        await _outbox.complete(op.id);
        await _reconcileDivergence(op, res.data?['data']);
      });
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // /me не может «не найтись» при валидной сессии — 404 это
        // не remote-delete сущности, а аномалия маршрута/аккаунта:
        // профиль (session identity) удалять нельзя — фиксируем
        // permanent failure, локальные данные сохраняются.
        if (op.entityType == 'profile') {
          if (_ownerId == op.ownerId) {
            final fresh = await _freshOp(op);
            if (fresh != null) {
              await _outbox.markFailed(fresh, 'PATCH /me returned 404');
            }
          }
          return;
        }
        // Сущности на сервере уже нет — убрать и локально. Но если
        // операция была переписана свежей мутацией в полёте —
        // 404 относится к старому намерению: не трогаем ни строку,
        // ни свежую операцию (её запрос получит свой ответ).
        await _db.transaction(() async {
          if (_ownerId != op.ownerId) return;
          if (await _freshOp(op) == null) return;
          await _dropLocalEntity(op);
        });
        return;
      }
      rethrow;
    }
  }

  Future<void> _pushDelete(OutboxEntry op) async {
    try {
      await _dio.delete<void>('${_collection(op)}/${op.entityId}');
      // Пока DELETE летел, сущность могла быть re-created локально:
      // compaction снял нашу операцию и поставил create/update.
      // Тогда dropLocalEntity снёс бы и строку, и свежие ops —
      // намерение «добавить заново» теряется. Свежие операции
      // сами определяют финальное состояние сущности.
      // Проверка + drop — одной транзакцией: мутация не может
      // проскочить в окно между ними.
      await _db.transaction(() async {
        if (_ownerId != op.ownerId) return;
        if (await _db.outboxEntryById(op.id) == null) return;
        await _dropLocalEntity(op);
      });
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        await _db.transaction(() async {
          if (_ownerId != op.ownerId) return;
          if (await _db.outboxEntryById(op.id) == null) return;
          // Уже удалён — delete повторяем и завершён.
          await _dropLocalEntity(op);
        });
        return;
      }
      rethrow;
    }
  }

  /// Физически удалить локальную сущность и её outbox-операции.
  /// Scope по ownerId — операция никогда не трогает чужие строки.
  /// Для списка покупок — каскадно снимает позиции и их операции
  /// (сервер удалил их вместе со списком).
  Future<void> _dropLocalEntity(OutboxEntry op) async {
    await _db.transaction(() async {
      switch (op.entityType) {
        case 'shopping_list':
          final items = await (_db.select(
            _db.shoppingItems,
          )..where((i) => i.listId.equals(op.entityId))).get();
          for (final item in items) {
            await (_db.delete(_db.shoppingItems)..where(
                  (i) => i.id.equals(item.id) & i.ownerId.equals(op.ownerId),
                ))
                .go();
            await _outbox.dropEntityOps(op.ownerId, item.id);
          }
          await (_db.delete(_db.shoppingLists)..where(
                (l) => l.id.equals(op.entityId) & l.ownerId.equals(op.ownerId),
              ))
              .go();
        case 'shopping_item':
          await (_db.delete(_db.shoppingItems)..where(
                (i) => i.id.equals(op.entityId) & i.ownerId.equals(op.ownerId),
              ))
              .go();
        case 'friendship':
          await (_db.delete(_db.friendships)..where(
                (f) =>
                    f.friendId.equals(op.entityId) &
                    f.ownerId.equals(op.ownerId),
              ))
              .go();
          // Кэш желаний друга без связи бесполезен; cached_user
          // удаляем только если на него нет других ссылок.
          await (_db.delete(_db.friendWishes)..where(
                (w) =>
                    w.friendId.equals(op.entityId) &
                    w.ownerId.equals(op.ownerId),
              ))
              .go();
          await _dropCachedUserIfOrphan(op.ownerId, op.entityId);
        case 'profile':
        // Профиль = session identity: строку не удаляем,
        // снимаются только операции (общий dropEntityOps ниже).
        default:
          await _dropWishWithImages(op.ownerId, op.entityId);
      }
      await _outbox.dropEntityOps(op.ownerId, op.entityId);
    });
  }

  // ── Media upload (ADR-015) ──────────────────────────────

  /// Доставить локальные изображения желаний в object storage
  /// через backend media API (presigned PUT → complete).
  ///
  /// Upload — не условие существования желания: ошибки одного
  /// изображения не блокируют остальные; transient-ошибка
  /// возвращает строку в `pending` для следующего sync-цикла,
  /// permanent (4xx) фиксируется `failed` и не retry'ится.
  Future<void> _pushWishMedia(String ownerId) async {
    for (final wish in await _db.wishesPendingImageUpload(ownerId)) {
      if (_ownerId != ownerId) return;
      // Сервер ещё не знает желание → media API ответит 404 на
      // entity check. Дождёмся успешного create — следующий цикл.
      if (await _outbox.hasUnsyncedCreate(ownerId, wish.id)) continue;
      await _uploadPrimaryImage(ownerId, wish);
    }
    for (final image in await _db.wishImagesPendingUpload(ownerId)) {
      if (_ownerId != ownerId) return;
      if (await _outbox.hasUnsyncedCreate(ownerId, image.wishId)) {
        continue;
      }
      await _uploadAdditionalImage(ownerId, image);
    }
  }

  Future<void> _uploadPrimaryImage(String ownerId, WishRow wish) async {
    final path = wish.imageUrl;
    if (path == null || Wish.isRemoteImageRef(path)) {
      // Строка помечена pending, но ссылка уже remote/пустая —
      // состояние выравниваем без запросов.
      await _db.setWishImageUploadState(ownerId, wish.id, status: 'uploaded');
      return;
    }
    final uploadId = wish.imageUploadId ?? const Uuid().v4();
    await _db.setWishImageUploadState(
      ownerId,
      wish.id,
      status: 'uploading',
      uploadId: uploadId,
    );
    try {
      final remoteUrl = await _uploadFile(
        entityId: wish.id,
        clientId: uploadId,
        path: path,
      );
      await _db.setWishImageUploadState(
        ownerId,
        wish.id,
        status: 'uploaded',
        remoteUrl: remoteUrl,
      );
      // remote_url уходит штатным update-op: сервер и другие
      // устройства получают его обычным PATCH — отдельный
      // протокол для изображений не нужен.
      await _outbox.enqueue(
        ownerId: ownerId,
        entityType: 'wish',
        entityId: wish.id,
        operation: OutboxOp.update,
        payload: {'image_url': remoteUrl},
      );
    } on DioException catch (e) {
      await _db.setWishImageUploadState(
        ownerId,
        wish.id,
        status: _isPermanentFailure(e) ? 'failed' : 'pending',
      );
      if (!_isPermanentFailure(e)) rethrow;
    }
  }

  Future<void> _uploadAdditionalImage(
    String ownerId,
    WishImageRow image,
  ) async {
    final path = image.localPath;
    if (path == null) {
      await _db.setWishImageRowUploadState(ownerId, image.id, status: 'failed');
      return;
    }
    if (image.remoteUrl != null) {
      await _db.setWishImageRowUploadState(
        ownerId,
        image.id,
        status: 'uploaded',
      );
      return;
    }
    final uploadId = image.uploadId ?? const Uuid().v4();
    await _db.setWishImageRowUploadState(
      ownerId,
      image.id,
      status: 'uploading',
      uploadId: uploadId,
    );
    try {
      final remoteUrl = await _uploadFile(
        entityId: image.wishId,
        clientId: uploadId,
        path: path,
      );
      await _db.setWishImageRowUploadState(
        ownerId,
        image.id,
        status: 'uploaded',
        remoteUrl: remoteUrl,
      );
    } on DioException catch (e) {
      await _db.setWishImageRowUploadState(
        ownerId,
        image.id,
        status: _isPermanentFailure(e) ? 'failed' : 'pending',
      );
      if (!_isPermanentFailure(e)) rethrow;
    }
  }

  /// request instructions → presigned PUT → complete → remote_url.
  /// `clientId` стабилен на локальную строку — retry не создаёт
  /// второй объект (сервер возвращает существующий upload).
  Future<String> _uploadFile({
    required String entityId,
    required String clientId,
    required String path,
  }) async {
    final file = File(path);
    final contentType = MediaPaths.contentTypeForPath(path);
    if (!file.existsSync() || contentType == null) {
      // Файл потерян или тип не в whitelist — retry бессмысленен.
      throw DioException(
        requestOptions: RequestOptions(),
        response: Response(requestOptions: RequestOptions(), statusCode: 422),
        type: DioExceptionType.badResponse,
      );
    }
    final instructions = await _mediaUploads.requestUpload(
      purpose: 'wish',
      entityId: entityId,
      contentType: contentType,
      size: file.lengthSync(),
      clientId: clientId,
    );
    return _mediaUploads.uploadAndConfirm(instructions, file);
  }

  /// 4xx — permanent: повтор того же файла даст тот же отказ.
  /// Отсутствие ответа (transport) и 5xx — retry позже.
  bool _isPermanentFailure(DioException e) {
    final status = e.response?.statusCode;
    return status != null && status >= 400 && status < 500;
  }

  /// Физическое удаление желания вместе с изображениями и
  /// локальными файлами (best-effort — в пределах транзакции
  /// вызывающего кода).
  Future<void> _dropWishWithImages(String ownerId, String wishId) async {
    // tombstone-строка: wishById отфильтровал бы её — читаем без фильтра.
    final local =
        await (_db.select(_db.wishes)
              ..where((w) => w.id.equals(wishId) & w.ownerId.equals(ownerId)))
            .getSingleOrNull();
    final paths = [
      if (local != null && !Wish.isRemoteImageRef(local.imageUrl))
        local.imageUrl!,
      ...await _db.deleteWishImages(ownerId, wishId),
    ];
    await (_db.delete(
      _db.wishes,
    )..where((w) => w.id.equals(wishId) & w.ownerId.equals(ownerId))).go();
    await deleteWishPhotoFiles(paths);
  }

  /// Удалить кэшированную проекцию пользователя, если на него
  /// больше никто не ссылается (нет живых friendship-строк и
  /// нет кэша его желаний у этого аккаунта).
  Future<void> _dropCachedUserIfOrphan(String ownerId, String userId) async {
    final stillFriend =
        await (_db.select(_db.friendships)..where(
              (f) =>
                  f.friendId.equals(userId) &
                  f.ownerId.equals(ownerId) &
                  f.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (stillFriend != null) return;
    final cachedWishes =
        await (_db.select(_db.friendWishes)..where(
              (w) => w.friendId.equals(userId) & w.ownerId.equals(ownerId),
            ))
            .get();
    if (cachedWishes.isNotEmpty) return;
    await (_db.delete(
      _db.cachedUsers,
    )..where((u) => u.userId.equals(userId) & u.ownerId.equals(ownerId))).go();
  }

  /// Записать server-представление сущности в локальную строку
  /// (созданной через outbox — та же identity, обновляем timestamps).
  ///
  /// [preserveLocal] — для позиции списка покупок: при расхождении
  /// сохранить локальные поля (непринятый сервером is_checked и
  /// пр.) — расхождение потом довозится [_reconcileDivergence].
  /// На чужой сущности (409, identity занята) — false: серверное
  /// представление применяется целиком.
  Future<void> _applyServerEntity(
    OutboxEntry op,
    dynamic data, {
    bool preserveLocal = true,
  }) async {
    if (data is! Map<String, dynamic>) return;
    switch (op.entityType) {
      case 'shopping_list':
        await (_db.update(_db.shoppingLists)..where(
              (l) => l.id.equals(op.entityId) & l.ownerId.equals(op.ownerId),
            ))
            .write(
              ShoppingListsCompanion(
                title: Value(data['title'] as String),
                createdAt: Value(DateTime.parse(data['created_at'] as String)),
                updatedAt: Value(DateTime.parse(data['updated_at'] as String)),
              ),
            );
      case 'shopping_item':
        // is_checked не принимается при POST /items (server default
        // false): если compaction схлопнул create+check в один create,
        // серверное представление расходится с локальным. При
        // расхождении локальные поля сохраняются — после complete
        // ставится follow-up update (см. [_reconcileDivergence]).
        final local = await _db.shoppingItemByIdAny(op.ownerId, op.entityId);
        final diverges =
            preserveLocal &&
            local != null &&
            local.deletedAt == null &&
            (local.title != data['title'] ||
                local.quantity != (data['quantity'] as int? ?? 1) ||
                local.isChecked != (data['is_checked'] as bool? ?? false));
        await (_db.update(_db.shoppingItems)..where(
              (i) => i.id.equals(op.entityId) & i.ownerId.equals(op.ownerId),
            ))
            .write(
              ShoppingItemsCompanion(
                title: Value(diverges ? local.title : data['title'] as String),
                quantity: Value(
                  diverges ? local.quantity : data['quantity'] as int? ?? 1,
                ),
                isChecked: Value(
                  diverges
                      ? local.isChecked
                      : data['is_checked'] as bool? ?? false,
                ),
                createdAt: Value(DateTime.parse(data['created_at'] as String)),
                updatedAt: Value(DateTime.parse(data['updated_at'] as String)),
              ),
            );
      case 'friendship':
        // Ответ POST/GET /friends — PublicUserResource: кэшируем
        // публичную проекцию, friendship-строка уже создана локально
        // (identity = friend_id, серверный Friendship-UUID не нужен).
        await _db
            .into(_db.cachedUsers)
            .insertOnConflictUpdate(
              CachedUsersCompanion(
                ownerId: Value(op.ownerId),
                userId: Value(data['id'] as String),
                name: Value(data['name'] as String?),
                username: Value(data['username'] as String?),
                avatarUrl: Value(data['avatar_url'] as String?),
                cachedAt: Value(DateTime.now()),
              ),
            );
      case 'profile':
        // Ответ PATCH /me — UserResource текущего пользователя.
        // profiles.id == op.ownerId — identity профиля = аккаунт.
        await _db.upsertProfile(_profileRow(op.ownerId, data));
      default:
        await _applyServerWish(op, data);
    }
  }

  /// Server-представление профиля → строка `profiles`
  /// (identity всегда [ownerId], не доверяем id из ответа —
  /// он может не совпасть только при баге, но писать под чужим
  /// owner нельзя в любом случае).
  ProfilesCompanion _profileRow(String ownerId, Map<String, dynamic> m) {
    return ProfilesCompanion(
      id: Value(ownerId),
      email: Value(m['email'] as String),
      name: Value(m['name'] as String?),
      username: Value(m['username'] as String?),
      avatarUrl: Value(m['avatar_url'] as String?),
      updatedAt: Value(
        m['updated_at'] != null
            ? DateTime.parse(m['updated_at'] as String)
            : null,
      ),
    );
  }

  /// Детектирует локальную мутацию, пришедшую, пока запрос операции
  /// был в полёте (compaction переписал payload той же записи).
  ///
  /// Ответ сервера в этом случае описывает УСТАРЕВШЕЕ состояние —
  /// применять его нельзя (затрёт свежую локаль). Create-операцию
  /// конвертируем в update с актуальным payload: сущность на сервере
  /// уже создана старым снимком, остаток доезжает PATCH'ом.
  ///
  /// Возвращает true, если операция уже переупорядочена и обычный
  /// apply+complete пропускать нельзя.
  Future<bool> _convergeInFlightMutation(OutboxEntry op) async {
    final fresh = await _db.outboxEntryById(op.id);
    if (fresh == null) {
      // Операции сняты в полёте. Если это был create, а локальная
      // сущность уже удалена/отмечена tombstone — запрос успел
      // создать её на сервере: delete-намерение пользователя должно
      // доехать отдельной операцией, иначе pull «воскресит» её.
      if (op.operation == OutboxOp.create && !await _entityLocallyPresent(op)) {
        await _outbox.enqueue(
          ownerId: op.ownerId,
          entityType: op.entityType,
          entityId: op.entityId,
          operation: OutboxOp.delete,
        );
      }
      return true;
    }
    if (fresh.payloadJson == op.payloadJson) return false;
    // Свежий payload может быть create-формы: убираем identity-поля —
    // PATCH не должен нести id / list_id (parent неизменяем).
    final payload = jsonDecode(fresh.payloadJson!) as Map<String, dynamic>
      ..remove('id')
      ..remove('list_id');
    await _outbox.complete(op.id);
    await _outbox.enqueue(
      ownerId: op.ownerId,
      entityType: op.entityType,
      entityId: op.entityId,
      operation: OutboxOp.update,
      payload: payload,
    );
    return true;
  }

  /// Локальная сущность существует и не tombstoned.
  /// ВАЖНО: `row?.deletedAt == null` неверно — физически удалённая
  /// строка (unsynced create + delete до sync) даёт null → «present»
  /// → delete-намерение после in-flight create терялось, а pull
  /// воскрешал сущность. Отсутствующая строка — это «нет сущности».
  Future<bool> _entityLocallyPresent(OutboxEntry op) async {
    return switch (op.entityType) {
      'shopping_list' =>
        await (_db.select(_db.shoppingLists)..where(
                  (l) =>
                      l.id.equals(op.entityId) &
                      l.ownerId.equals(op.ownerId) &
                      l.deletedAt.isNull(),
                ))
                .getSingleOrNull() !=
            null,
      'shopping_item' =>
        await (_db.select(_db.shoppingItems)..where(
                  (i) =>
                      i.id.equals(op.entityId) &
                      i.ownerId.equals(op.ownerId) &
                      i.deletedAt.isNull(),
                ))
                .getSingleOrNull() !=
            null,
      'friendship' =>
        await (_db.select(_db.friendships)..where(
                  (f) =>
                      f.friendId.equals(op.entityId) &
                      f.ownerId.equals(op.ownerId) &
                      f.deletedAt.isNull(),
                ))
                .getSingleOrNull() !=
            null,
      'profile' =>
        // profiles.id == ownerId (entityId профиля = аккаунт).
        await _db.profileById(op.entityId) != null,
      _ =>
        await (_db.select(_db.wishes)..where(
                  (w) =>
                      w.id.equals(op.entityId) &
                      w.ownerId.equals(op.ownerId) &
                      w.deletedAt.isNull(),
                ))
                .getSingleOrNull() !=
            null,
    };
  }

  /// Follow-up для позиции, чьё локальное состояние расходится с
  /// принятым сервером (например, `is_checked` не читается при create).
  /// Вызывается ПОСЛЕ `complete` исходной операции — иначе compaction
  /// схлопнул бы update в ещё не снятый create и потерял бы его.
  Future<void> _reconcileDivergence(OutboxEntry op, dynamic data) async {
    if (op.entityType != 'shopping_item') return;
    if (data is! Map<String, dynamic>) return;
    final local = await _db.shoppingItemByIdAny(op.ownerId, op.entityId);
    if (local == null || local.deletedAt != null) return;
    if (local.title == data['title'] &&
        local.quantity == (data['quantity'] as int? ?? 1) &&
        local.isChecked == (data['is_checked'] as bool? ?? false)) {
      return;
    }
    await _outbox.enqueue(
      ownerId: op.ownerId,
      entityType: 'shopping_item',
      entityId: local.id,
      operation: OutboxOp.update,
      payload: {
        'title': local.title,
        'quantity': local.quantity,
        'is_checked': local.isChecked,
      },
    );
  }

  /// Записать server-представление желания в локальную строку
  /// (созданной через outbox — та же identity, обновляем timestamps).
  Future<void> _applyServerWish(OutboxEntry op, dynamic data) async {
    if (data is! Map<String, dynamic>) return;
    final serverImage = data['image_url'] as String?;
    // Локальный файл не уходит в API — серверный null не должен
    // затирать локальное фото (до upload-эндпоинта).
    final local = await _db.wishById(op.ownerId, op.entityId);
    final localImage = local?.imageUrl;
    // Сервер не знает локальный файл — сохраняем его. Remote URL,
    // уже подтверждённый media upload, но ещё не дошедший через
    // update-op, тоже сохраняем (не затираем серверным null).
    final keepLocal =
        serverImage == null &&
        localImage != null &&
        (!Wish.isRemoteImageRef(localImage) ||
            local?.imageUploadStatus == 'uploaded');
    await (_db.update(_db.wishes)..where(
          (w) => w.id.equals(op.entityId) & w.ownerId.equals(op.ownerId),
        ))
        .write(
          WishesCompanion(
            title: Value(data['title'] as String),
            description: Value(data['description'] as String?),
            price: Value(data['price'] as int?),
            link: Value(data['link'] as String?),
            imageUrl: Value(keepLocal ? localImage : serverImage),
            createdAt: Value(DateTime.parse(data['created_at'] as String)),
            updatedAt: Value(DateTime.parse(data['updated_at'] as String)),
          ),
        );
  }

  Future<void> _handleHttpError(OutboxEntry op, DioException e) async {
    // Ответ пришёл после detach/смены аккаунта — он относится к
    // чужой сессии. 401 старого токена не должен сносить
    // credentials нового аккаунта (_onUnauthorized →
    // clearCredentials пишет в глобальное хранилище).
    if (_ownerId != op.ownerId) return;
    final code = e.response?.statusCode;
    final message =
        (e.response?.data is Map ? (e.response!.data as Map)['message'] : null)
            ?.toString() ??
        e.message ??
        'network error';

    if (code == 401) {
      _authExpired = true;
      throw const _AuthExpired();
    }
    // Операция могла быть замещена/переписана новой мутацией, пока
    // запрос был в полёте: ответ относится к устаревшему намерению —
    // markFailed по старому ответу навсегда оставил бы свежую
    // операцию в 'failed' (silent divergence), markRetry со старым
    // snapshot-attempts — наложил бы чужой backoff.
    final fresh = await _freshOp(op);
    if (fresh == null) return;
    if (code == 422) {
      // Permanent failure. Для delete: сервер отказал — намерение не
      // выполнено, tombstone снимаем, сущность возвращается в список
      // (пользователь видит её снова и может повторить удаление).
      if (op.operation == OutboxOp.delete) {
        await _restoreTombstone(op);
      }
      await _outbox.markFailed(fresh, message);
      return;
    }
    // 5xx, timeout, connection error, прочее — retry с backoff.
    await _outbox.markRetry(fresh, message);
  }

  /// Снять tombstone у сущности, которую сервер отказался удалять.
  Future<void> _restoreTombstone(OutboxEntry op) async {
    switch (op.entityType) {
      case 'shopping_list':
        await (_db.update(_db.shoppingLists)..where(
              (l) => l.id.equals(op.entityId) & l.ownerId.equals(op.ownerId),
            ))
            .write(const ShoppingListsCompanion(deletedAt: Value(null)));
      case 'shopping_item':
        await (_db.update(_db.shoppingItems)..where(
              (i) => i.id.equals(op.entityId) & i.ownerId.equals(op.ownerId),
            ))
            .write(const ShoppingItemsCompanion(deletedAt: Value(null)));
      case 'friendship':
        await (_db.update(_db.friendships)..where(
              (f) =>
                  f.friendId.equals(op.entityId) & f.ownerId.equals(op.ownerId),
            ))
            .write(const FriendshipsCompanion(deletedAt: Value(null)));
      case 'profile':
      // У профиля нет tombstone — delete-операций не бывает.
      default:
        await (_db.update(_db.wishes)..where(
              (w) => w.id.equals(op.entityId) & w.ownerId.equals(op.ownerId),
            ))
            .write(const WishesCompanion(deletedAt: Value(null)));
    }
  }

  // ── Pull (snapshot reconcile) ─────────────────────────────

  /// Полные snapshot'ы `GET /wishes` + `GET /shopping-lists` +
  /// `GET /friends` → reconcile в одной транзакции. Локальные
  /// данные не трогаются до успешных ответов и полного парсинга
  /// всех выборок.
  Future<void> _pull() async {
    final ownerId = _ownerId;
    if (ownerId == null) return;

    final Response<Map<String, dynamic>> wishesRes;
    final Response<Map<String, dynamic>> listsRes;
    final Response<Map<String, dynamic>> friendsRes;
    final Response<Map<String, dynamic>> meRes;
    try {
      wishesRes = await _dio.get<Map<String, dynamic>>('/wishes');
      listsRes = await _dio.get<Map<String, dynamic>>('/shopping-lists');
      friendsRes = await _dio.get<Map<String, dynamic>>('/friends');
      meRes = await _dio.get<Map<String, dynamic>>('/me');
    } on DioException catch (e) {
      // 401 на pull — та же auth-expired семантика, что и на push:
      // иначе протухший токен без pending-операций вечно жил бы
      // как «offline», сессия не сбрасывалась бы никогда.
      if (e.response?.statusCode == 401 && _ownerId == ownerId) {
        _authExpired = true;
        throw const _AuthExpired();
      }
      rethrow;
    }
    final rawWishes = wishesRes.data?['data'];
    final rawLists = listsRes.data?['data'];
    final rawFriends = friendsRes.data?['data'];
    final rawMe = meRes.data?['data'];
    if (rawWishes is! List ||
        rawLists is! List ||
        rawFriends is! List ||
        rawMe is! Map<String, dynamic>) {
      throw StateError('Malformed snapshot response');
    }
    // Парсинг до транзакции — malformed ответ не должен
    // инициировать reconcile и удаление локальных данных.
    // Аккаунт мог смениться, пока запрос был в полёте — reconcile
    // применяем только к тому owner_id, под которым начали.
    if (_ownerId != ownerId) return;

    final remoteWishes = rawWishes.map(_parseWishRow).toList();
    final remoteWishIds = remoteWishes.map((w) => w.id.value).toSet();

    final remoteLists = <ShoppingListsCompanion>[];
    final remoteListIds = <String>{};
    final remoteItems = <ShoppingItemsCompanion>[];
    final remoteItemIds = <String>{};
    final remoteItemListIds = <String, String>{};
    for (final raw in rawLists) {
      final list = _parseShoppingListRow(raw as Map<String, dynamic>);
      remoteLists.add(list);
      remoteListIds.add(list.id.value);
      final items = raw['items'];
      if (items is List) {
        for (final rawItem in items) {
          final item = _parseShoppingItemRow(
            rawItem as Map<String, dynamic>,
            list.id.value,
          );
          remoteItems.add(item);
          remoteItemIds.add(item.id.value);
          remoteItemListIds[item.id.value] = list.id.value;
        }
      }
    }

    final remoteFriendIds = rawFriends
        .map((raw) => (raw as Map<String, dynamic>)['id'] as String)
        .toSet();

    // Профиль — snapshot собственного аккаунта; парсинг до
    // транзакции, identity = ownerId (см. [_profileRow]).
    final remoteProfile = _profileRow(ownerId, rawMe);

    await _db.transaction(() async {
      // Re-check ВНУТРИ транзакции: detach + clearAccountData могут
      // завершиться между внешней проверкой и этой транзакцией —
      // иначе snapshot воскресит только что вычищенные строки
      // разлогиненного аккаунта.
      if (_ownerId != ownerId) return;
      final pending = await _db.pendingEntityIds(ownerId);

      // Upsert только «чистых» сущностей: pending/failed-операция
      // означает, что локальное состояние новее серверного —
      // не затираем. Позиция дополнительно защищена, если
      // незавершённая операция висит на её родительском списке.
      for (final row in remoteWishes) {
        if (pending.contains(row.id.value)) continue;
        var merged = row;
        if (row.imageUrl.value == null) {
          // Сервер не знает о локальном файле — сохраняем его
          // в строке, чтобы фото не пропадало после reconcile.
          // То же для remote URL после upload: update-op ещё в
          // outbox → локальное значение новее серверного null.
          final local = await _db.wishById(ownerId, row.id.value);
          final localImage = local?.imageUrl;
          if (localImage != null &&
              (!Wish.isRemoteImageRef(localImage) ||
                  local?.imageUploadStatus == 'uploaded')) {
            merged = row.copyWith(imageUrl: Value(localImage));
          }
        }
        await _db
            .into(_db.wishes)
            .insertOnConflictUpdate(merged.copyWith(ownerId: Value(ownerId)));
      }
      for (final row in remoteLists) {
        if (!pending.contains(row.id.value)) {
          await _db
              .into(_db.shoppingLists)
              .insertOnConflictUpdate(row.copyWith(ownerId: Value(ownerId)));
        }
      }
      for (final row in remoteItems) {
        if (!pending.contains(row.id.value) &&
            !pending.contains(row.listId.value)) {
          await _db
              .into(_db.shoppingItems)
              .insertOnConflictUpdate(row.copyWith(ownerId: Value(ownerId)));
        }
      }

      // Remote-delete detection: локальная чистая сущность, которой
      // нет в snapshot → удалена на другом устройстве → удалить и тут.
      final localWishes = await (_db.select(
        _db.wishes,
      )..where((w) => w.ownerId.equals(ownerId))).get();
      for (final w in localWishes) {
        if (!remoteWishIds.contains(w.id) && !pending.contains(w.id)) {
          // Каскад: изображения желания и их файлы уходят вместе
          // с сущностью — не остаёмся с orphan-строками/файлами.
          await _dropWishWithImages(ownerId, w.id);
        }
      }
      final localLists = await (_db.select(
        _db.shoppingLists,
      )..where((l) => l.ownerId.equals(ownerId))).get();
      for (final l in localLists) {
        if (!remoteListIds.contains(l.id) && !pending.contains(l.id)) {
          await (_db.delete(
            _db.shoppingLists,
          )..where((x) => x.id.equals(l.id))).go();
        }
      }
      final localItems = await (_db.select(
        _db.shoppingItems,
      )..where((i) => i.ownerId.equals(ownerId))).get();
      for (final i in localItems) {
        if (!remoteItemIds.contains(i.id) && !pending.contains(i.id)) {
          await (_db.delete(
            _db.shoppingItems,
          )..where((x) => x.id.equals(i.id))).go();
        }
      }

      // Friendships: snapshot `GET /friends` — список
      // PublicUserResource. Identity = friend_id (entityId outbox);
      // чистые сущности upsert'им, отсутствующие в snapshot —
      // удаляем вместе с их кэшем желаний.
      for (final raw in rawFriends) {
        final m = raw as Map<String, dynamic>;
        final friendId = m['id'] as String;
        await _db
            .into(_db.cachedUsers)
            .insertOnConflictUpdate(
              CachedUsersCompanion(
                ownerId: Value(ownerId),
                userId: Value(friendId),
                name: Value(m['name'] as String?),
                username: Value(m['username'] as String?),
                avatarUrl: Value(m['avatar_url'] as String?),
                cachedAt: Value(DateTime.now()),
              ),
            );
        if (pending.contains(friendId)) continue;
        final existing = await _db.friendshipByIdAny(ownerId, friendId);
        if (existing == null) {
          final now = DateTime.now();
          await _db
              .into(_db.friendships)
              .insert(
                FriendshipsCompanion(
                  ownerId: Value(ownerId),
                  friendId: Value(friendId),
                  createdAt: Value(now),
                  updatedAt: Value(now),
                ),
              );
        } else if (existing.deletedAt != null) {
          // Чистая tombstone-строка без операций, а сервер считает
          // пару живой — снимаем tombstone (защитная консистентность).
          await (_db.update(_db.friendships)..where(
                (f) => f.friendId.equals(friendId) & f.ownerId.equals(ownerId),
              ))
              .write(const FriendshipsCompanion(deletedAt: Value(null)));
        }
      }
      final localFriendships = await (_db.select(
        _db.friendships,
      )..where((f) => f.ownerId.equals(ownerId))).get();
      for (final f in localFriendships) {
        if (!remoteFriendIds.contains(f.friendId) &&
            !pending.contains(f.friendId)) {
          await (_db.delete(_db.friendships)..where(
                (x) =>
                    x.friendId.equals(f.friendId) & x.ownerId.equals(ownerId),
              ))
              .go();
          await (_db.delete(_db.friendWishes)..where(
                (w) =>
                    w.friendId.equals(f.friendId) & w.ownerId.equals(ownerId),
              ))
              .go();
          await _dropCachedUserIfOrphan(ownerId, f.friendId);
        }
      }

      // Profile: pending/failed profile-операция (entityId ==
      // ownerId) защищает локальное состояние — local intent wins;
      // чистый профиль — server snapshot wins.
      if (!pending.contains(ownerId)) {
        await _db.upsertProfile(remoteProfile);
      }
    });
  }

  ShoppingListsCompanion _parseShoppingListRow(Map<String, dynamic> m) {
    return ShoppingListsCompanion(
      id: Value(m['id'] as String),
      title: Value(m['title'] as String),
      createdAt: Value(DateTime.parse(m['created_at'] as String)),
      updatedAt: Value(DateTime.parse(m['updated_at'] as String)),
    );
  }

  ShoppingItemsCompanion _parseShoppingItemRow(
    Map<String, dynamic> m,
    String listId,
  ) {
    return ShoppingItemsCompanion(
      id: Value(m['id'] as String),
      listId: Value(listId),
      title: Value(m['title'] as String),
      quantity: Value(m['quantity'] as int? ?? 1),
      isChecked: Value(m['is_checked'] as bool? ?? false),
      createdAt: Value(DateTime.parse(m['created_at'] as String)),
      updatedAt: Value(DateTime.parse(m['updated_at'] as String)),
    );
  }

  WishesCompanion _parseWishRow(dynamic item) {
    final m = item as Map<String, dynamic>;
    return WishesCompanion(
      id: Value(m['id'] as String),
      title: Value(m['title'] as String),
      description: Value(m['description'] as String?),
      price: Value(m['price'] as int?),
      link: Value(m['link'] as String?),
      imageUrl: Value(m['image_url'] as String?),
      createdAt: Value(DateTime.parse(m['created_at'] as String)),
      updatedAt: Value(DateTime.parse(m['updated_at'] as String)),
    );
  }
}

/// Маркер истёкшей сессии — останавливает sync и передаётся в
/// session-слой (network failure — НЕ то же самое, что 401).
class _AuthExpired implements Exception {
  const _AuthExpired();
}

/// Состояние синхронизации для UI.
class SyncStatusNotifier extends Notifier<SyncStatus> {
  @override
  SyncStatus build() => SyncStatus.idle;

  void set(SyncStatus status) => state = status;
}

final syncStatusProvider = NotifierProvider<SyncStatusNotifier, SyncStatus>(
  SyncStatusNotifier.new,
);

/// Число незавершённых outbox-операций текущего аккаунта
/// (pending + failed). Используется UI для микро-индикации
/// «не синхронизировано» — без неё пользователь не видит,
/// что локальные изменения ещё не доехали до сервера.
final pendingOutboxCountProvider = StreamProvider<int>((ref) {
  final userId = ref.watch(preferencesServiceProvider).currentUserId();
  if (userId == null) return Stream.value(0);
  return ref.watch(appDatabaseProvider).watchOutboxCount(userId);
});

/// Провайдер SyncEngine. Живёт всю сессию; attach/detach
/// управляется AppSessionController. В тестах без сервера
/// engine просто не находит сеть — outbox копит операции.
final syncEngineProvider = Provider<SyncEngine>((ref) {
  final engine = SyncEngine(
    db: ref.read(appDatabaseProvider),
    dio: ref.read(apiClientProvider),
    onUnauthorized: () => _onUnauthorized(ref),
    onStatus: ref.read(syncStatusProvider.notifier).set,
  );
  ref.onDispose(engine.detach);
  return engine;
});

void _onUnauthorized(Ref ref) {
  // 401 = серверная сессия невалидна. Чистим credentials и даём
  // session-контроллеру пересчитать состояние → NeedsAuth.
  // Локальные данные аккаунта сохраняются (owner-scoped) — после
  // повторного входа того же пользователя они на месте.
  ref.read(authRepositoryProvider).clearCredentials();
  ref.invalidate(appSessionControllerProvider);
}

/// Фореграунд-триггер: при возврате в app — sync.
/// Реализован как observer; регистрируется в App.
class SyncLifecycleObserver extends WidgetsBindingObserver {
  SyncLifecycleObserver(this._ref);

  final Ref _ref;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_ref.read(syncEngineProvider).requestSync());
    }
  }
}

final syncLifecycleObserverProvider = Provider<SyncLifecycleObserver>(
  (ref) => SyncLifecycleObserver(ref),
);
