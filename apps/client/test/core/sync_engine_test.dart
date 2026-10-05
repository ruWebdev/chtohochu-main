import 'dart:async';
import 'dart:io';

import 'package:chtohochu/core/database/app_database.dart';
import 'package:chtohochu/core/database/legacy_migration.dart';
import 'package:chtohochu/core/media/media_upload_service.dart';
import 'package:chtohochu/core/services/preferences_service.dart';
import 'package:chtohochu/core/services/secure_storage_service.dart';
import 'package:chtohochu/core/sync/outbox_store.dart';
import 'package:chtohochu/core/sync/sync_engine.dart';
import 'package:chtohochu/features/auth/data/auth_repository.dart';
import 'package:chtohochu/features/wishes/data/wish_repository.dart';
import 'package:chtohochu/features/wishes/domain/wish.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_api.dart';
import '../helpers/test_app.dart';

/// SyncEngine: push outbox → API, pull snapshot → reconcile,
/// HTTP-семантика, retry/backoff, account isolation.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  const ownerA = 'user-a';
  const ownerB = 'user-b';
  const token = 'token-a';

  late AppDatabase db;
  late FakeApiAdapter api;
  late _GatedAdapter gated;
  late Dio dio;
  late SyncEngine engine;
  late DriftWishRepository repo;
  late PreferencesService prefs;
  late List<SyncStatus> statuses;
  late bool unauthorizedCalled;

  Future<List<OutboxEntry>> outboxOf(String ownerId) {
    return (db.select(
      db.outboxEntries,
    )..where((o) => o.ownerId.equals(ownerId))).get();
  }

  Future<WishRow?> rowOf(String id) =>
      (db.select(db.wishes)..where((w) => w.id.equals(id))).getSingleOrNull();

  Future<void> sync() => engine.requestSync();

  setUp(() async {
    setupTestStorage(
      preferences: {'current_user_id': ownerA},
      secureStorage: {'access_token': token},
    );
    prefs = PreferencesService(await SharedPreferences.getInstance());
    db = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    repo = DriftWishRepository(db, prefs);
    api = FakeApiAdapter(autoUserId: ownerA);
    gated = _GatedAdapter(api);
    dio = createTestApiClient(gated);
    statuses = [];
    unauthorizedCalled = false;
    engine = SyncEngine(
      db: db,
      dio: dio,
      onUnauthorized: () => unauthorizedCalled = true,
      onStatus: statuses.add,
    );
    engine.attach(ownerA);
    await sync(); // стартовый pull на пустом сервере
    statuses.clear();
  });

  tearDown(() async {
    engine.detach();
    await db.close();
  });

  group('push', () {
    test('create → POST с тем же UUID → outbox снят', () async {
      final wish = await repo.createWish(title: 'Книга', price: 500);
      await sync();

      expect(await outboxOf(ownerA), isEmpty);
      final server = api.wishesOf(ownerA).single;
      expect(server['id'], wish.id); // identity не перемаплена
      expect(server['title'], 'Книга');
      // Локальные timestamps обновлены серверными (идемпотентно).
      expect(await rowOf(wish.id), isNotNull);
      expect(statuses, contains(SyncStatus.idle));
    });

    test('lost response → retry с тем же UUID → 409 → reconcile', () async {
      final wish = await repo.createWish(title: 'Книга');
      // Сервер «уже принял» create (ответ потерян при первом sync).
      api.seedWish(ownerA, {
        'id': wish.id,
        'title': 'Книга',
        'description': null,
        'price': 500,
        'link': null,
        'image_url': null,
        'created_at': '2026-01-01T00:00:00.000Z',
        'updated_at': '2026-01-02T00:00:00.000Z',
      });

      await sync();

      // POST → 409 → GET /wishes/{id} → apply → outbox снят,
      // дубликата ни на сервере, ни локально.
      expect(api.wishesOf(ownerA), hasLength(1));
      expect(await outboxOf(ownerA), isEmpty);
      final row = (await rowOf(wish.id))!;
      expect(row.title, 'Книга');
      // Drift хранит unix-секунды — сравниваем момент, а не объект.
      expect(
        row.updatedAt.millisecondsSinceEpoch,
        DateTime.utc(2026, 1, 2).millisecondsSinceEpoch,
      );
    });

    test('409, но сущность недоступна (чужой UUID) → операция '
        'невыполнима, локальная сущность снята', () async {
      final wish = await repo.createWish(title: 'Книга');
      // 409 на create + 404 на reconcile-GET: UUID занят чужим
      // ресурсом — серверное состояние нам недоступно.
      api.failures['POST /wishes'] = 409;
      api.failures['GET /wishes/'] = 404;

      await sync();

      expect(await rowOf(wish.id), isNull);
      expect(await outboxOf(ownerA), isEmpty);
    });

    test('update → PATCH → сервер обновлён, outbox снят', () async {
      final wish = await repo.createWish(title: 'Книга');
      await sync();

      await repo.updateWish(wish.copyWith(title: 'Новая книга'));
      await sync();

      expect(api.wishesOf(ownerA).single['title'], 'Новая книга');
      expect(await outboxOf(ownerA), isEmpty);
    });

    test('update → 404 → сущность удалена локально, outbox снят', () async {
      final wish = await repo.createWish(title: 'Книга');
      await sync();
      api.deleteServerWish(ownerA, wish.id); // удалено «с другого устройства»

      await repo.updateWish(wish.copyWith(title: 'v2'));
      await sync();

      expect(await rowOf(wish.id), isNull);
      expect(await outboxOf(ownerA), isEmpty);
      expect(api.wishesOf(ownerA), isEmpty);
    });

    test('delete → 204 → физическое удаление локально и на сервере', () async {
      final wish = await repo.createWish(title: 'Книга');
      await sync();

      await repo.deleteWish(wish.id);
      expect(await repo.getWishes(), isEmpty); // сразу скрыто из UI
      await sync();

      expect(await rowOf(wish.id), isNull);
      expect(await outboxOf(ownerA), isEmpty);
      expect(api.wishesOf(ownerA), isEmpty);
    });

    test('delete → 404 → считается выполненным', () async {
      final wish = await repo.createWish(title: 'Книга');
      await sync();
      api.deleteServerWish(ownerA, wish.id);

      await repo.deleteWish(wish.id);
      await sync();

      expect(await rowOf(wish.id), isNull);
      expect(await outboxOf(ownerA), isEmpty);
    });

    test('422 → permanent failure: статус failed, без ретраев', () async {
      api.failures['POST /wishes'] = 422;
      await repo.createWish(title: 'Книга');
      await sync();

      final op = (await outboxOf(ownerA)).single;
      expect(op.status, 'failed');
      expect(op.lastError, isNotNull);

      // Повторный sync не переотправляет failed-операцию.
      api.failures.clear();
      await sync();
      expect(api.wishesOf(ownerA), isEmpty);
      // Локальная сущность при этом не потеряна.
      expect(await repo.getWishes(), hasLength(1));
    });

    test('500 → retry: attempts++, nextRetryAt, сущность сохранена', () async {
      api.failures['POST /wishes'] = 500;
      await repo.createWish(title: 'Книга');
      await sync();

      final op = (await outboxOf(ownerA)).single;
      expect(op.status, 'pending');
      expect(op.attempts, 1);
      expect(op.nextRetryAt!.isAfter(DateTime.now()), isTrue);
      expect(await repo.getWishes(), hasLength(1));

      // Сбой устранён + backoff истёк → sync завершает операцию.
      api.failures.clear();
      await (db.update(db.outboxEntries)..where((o) => o.id.equals(op.id)))
          .write(const OutboxEntriesCompanion(nextRetryAt: Value(null)));
      await sync();
      expect(api.wishesOf(ownerA), hasLength(1));
      expect(await outboxOf(ownerA), isEmpty);
    });

    test('network failure → retry, статус offline', () async {
      api.failures['POST /wishes'] = 'network';
      api.failures['GET /wishes'] = 'network';
      await repo.createWish(title: 'Книга');
      await sync();

      final op = (await outboxOf(ownerA)).single;
      expect(op.attempts, 1);
      expect(op.status, 'pending');
      expect(statuses, contains(SyncStatus.offline));
      expect(await repo.getWishes(), hasLength(1)); // локально осталось
    });

    test('401 → sync остановлен, session уведомлён, outbox сохранён', () async {
      api.failures['POST /wishes'] = 401;
      await repo.createWish(title: 'Книга');
      await sync();

      expect(unauthorizedCalled, isTrue);
      expect(statuses, contains(SyncStatus.unauthorized));
      // Операция НЕ потеряна — ретрай после повторной авторизации.
      expect((await outboxOf(ownerA)).single.status, 'pending');

      // Дальнейшие запросы sync не выполняются до смены сессии.
      api.failures.clear();
      await sync();
      expect(api.wishesOf(ownerA), isEmpty);
    });
  });

  group('outbox state machine (через HTTP-журнал)', () {
    // B: create offline → update offline → sync → один POST
    // с финальным состоянием, без PATCH.
    test('create→update: уходит один POST с финальным payload', () async {
      final wish = await repo.createWish(title: 'v1');
      await repo.updateWish(wish.copyWith(title: 'v2', price: 100));
      api.requests.clear();

      await sync();

      final mutating = api.requests.where((r) => !r.startsWith('GET'));
      expect(mutating, ['POST /wishes']);
      expect(api.wishesOf(ownerA).single['title'], 'v2');
      expect(api.wishesOf(ownerA).single['price'], 100);
    });

    // C: create offline → delete offline → sync → ни POST, ни DELETE.
    test('create→delete: на сервер вообще ничего не уходит', () async {
      final wish = await repo.createWish(title: 'v1');
      await repo.deleteWish(wish.id);
      api.requests.clear();

      await sync();

      final mutating = api.requests.where((r) => !r.startsWith('GET'));
      expect(mutating, isEmpty);
      expect(api.wishesOf(ownerA), isEmpty);
    });

    // D: create online → update offline → delete offline → sync →
    // только DELETE.
    test('create→sync→update→delete: уходит только DELETE', () async {
      final wish = await repo.createWish(title: 'v1');
      await sync();

      await repo.updateWish(wish.copyWith(title: 'v2'));
      await repo.deleteWish(wish.id);
      api.requests.clear();

      await sync();

      final mutating = api.requests.where((r) => !r.startsWith('GET'));
      expect(mutating, ['DELETE /wishes/${wish.id}']);
      expect(api.wishesOf(ownerA), isEmpty);
    });

    // E: update → update → sync → один PATCH с последним состоянием.
    test('update→update: уходит один PATCH', () async {
      final wish = await repo.createWish(title: 'v1');
      await sync();

      await repo.updateWish(wish.copyWith(title: 'v2'));
      await repo.updateWish(wish.copyWith(title: 'v3'));
      api.requests.clear();

      await sync();

      final mutating = api.requests.where((r) => !r.startsWith('GET'));
      expect(mutating, ['PATCH /wishes/${wish.id}']);
      expect(api.wishesOf(ownerA).single['title'], 'v3');
    });
  });

  group('failed operation recovery', () {
    test('failed create → edit → sync отправляет POST заново', () async {
      api.failures['POST /wishes'] = 422;
      final wish = await repo.createWish(title: 'Битая');
      await sync();
      expect((await outboxOf(ownerA)).single.status, 'failed');

      // Пользователь исправил данные — update реанимирует create.
      api.failures.clear();
      await repo.updateWish(wish.copyWith(title: 'Исправленная'));
      final op = (await outboxOf(ownerA)).single;
      expect(op.operation, 'create');
      expect(op.status, 'pending');

      await sync();
      expect(api.wishesOf(ownerA).single['title'], 'Исправленная');
      expect(await outboxOf(ownerA), isEmpty);
    });

    test('failed update → новый update → sync отправляет актуальное', () async {
      final wish = await repo.createWish(title: 'Книга');
      await sync();

      api.failures['PATCH /wishes'] = 422;
      await repo.updateWish(wish.copyWith(title: 'Битое обновление'));
      await sync();
      expect((await outboxOf(ownerA)).single.status, 'failed');

      api.failures.clear();
      await repo.updateWish(wish.copyWith(title: 'Финальное'));
      await sync();

      expect(api.wishesOf(ownerA).single['title'], 'Финальное');
      expect(await outboxOf(ownerA), isEmpty);
    });

    test('failed create → delete: ни одного HTTP-запроса', () async {
      api.failures['POST /wishes'] = 422;
      final wish = await repo.createWish(title: 'Битая');
      await sync();
      expect((await outboxOf(ownerA)).single.status, 'failed');

      // Сервер никогда не принимал сущность → delete локальный.
      api.requests.clear();
      await repo.deleteWish(wish.id);
      await sync();

      expect(api.requests.where((r) => !r.startsWith('GET')), isEmpty);
      expect(await rowOf(wish.id), isNull);
      expect(await outboxOf(ownerA), isEmpty);
    });

    test('failed delete: сущность возвращается в UI, retry возможен', () async {
      final wish = await repo.createWish(title: 'Книга');
      await sync();

      api.failures['DELETE /wishes'] = 422;
      await repo.deleteWish(wish.id);
      await sync();

      // Сервер отказал — желание возвращено пользователю.
      final op = (await outboxOf(ownerA)).single;
      expect(op.status, 'failed');
      expect(await repo.getWishes(), hasLength(1));

      // Повторное удаление заменяет failed-операцию и доезжает.
      api.failures.clear();
      await repo.deleteWish(wish.id);
      await sync();

      expect(api.wishesOf(ownerA), isEmpty);
      expect(await rowOf(wish.id), isNull);
      expect(await outboxOf(ownerA), isEmpty);
    });

    test('failed delete + update → новое намерение замещает failed', () async {
      final wish = await repo.createWish(title: 'Книга');
      await sync();

      api.failures['DELETE /wishes'] = 422;
      await repo.deleteWish(wish.id);
      await sync();
      expect((await outboxOf(ownerA)).single.status, 'failed');
      // Tombstone снят — желание снова редактируемо.

      // Пользователь передумал удалять и отредактировал: update
      // обязан заместить failed delete, а не тихо пропасть.
      final local = (await repo.getWishById(wish.id))!;
      await repo.updateWish(local.copyWith(title: 'Книга (новая)'));
      final op = (await outboxOf(ownerA)).single;
      expect(op.operation, 'update');
      expect(op.status, 'pending');

      api.failures.clear();
      await sync();

      expect(api.wishesOf(ownerA).single['title'], 'Книга (новая)');
      expect(await outboxOf(ownerA), isEmpty);
    });
  });

  group('pull snapshot', () {
    Map<String, dynamic> serverWish(String id, String title) => {
      'id': id,
      'title': title,
      'description': null,
      'price': null,
      'link': null,
      'image_url': null,
      'created_at': '2026-01-01T00:00:00.000Z',
      'updated_at': '2026-01-01T00:00:00.000Z',
    };

    test('remote новое желание → появляется локально', () async {
      api.seedWish(ownerA, serverWish('srv-1', 'Серверное'));
      await sync();
      expect((await repo.getWishes()).single.title, 'Серверное');
    });

    test('remote изменение → локальная строка обновляется', () async {
      final wish = await repo.createWish(title: 'Книга');
      await sync();
      api.seedWish(ownerA, serverWish(wish.id, 'Изменено на сервере'));
      await sync();
      expect((await rowOf(wish.id))!.title, 'Изменено на сервере');
    });

    test('remote delete → локальная чистая сущность удаляется', () async {
      final wish = await repo.createWish(title: 'Книга');
      await sync();
      api.deleteServerWish(ownerA, wish.id);
      await sync();
      expect(await rowOf(wish.id), isNull);
    });

    test('remote delete → изображения желания каскадно удаляются', () async {
      final wish = await repo.createWish(
        title: 'Фото',
        imageUrl: '/tmp/primary.jpg',
        additionalImagePaths: ['/tmp/extra.jpg'],
      );
      await sync();
      expect(await db.wishImagesOf(ownerA, wish.id), hasLength(1));

      api.deleteServerWish(ownerA, wish.id);
      await sync();

      expect(await rowOf(wish.id), isNull);
      expect(await db.wishImagesOf(ownerA, wish.id), isEmpty);
    });

    test('server image_url: null не стирает локальные фото '
        '(primary path + additional rows)', () async {
      final wish = await repo.createWish(
        title: 'Фото',
        imageUrl: '/tmp/primary.jpg',
        additionalImagePaths: ['/tmp/extra.jpg'],
      );
      await sync(); // push: payload.image_url = null (локальный путь)
      await sync(); // pull: сервер отдаёт null — локальное остаётся

      expect((await rowOf(wish.id))!.imageUrl, '/tmp/primary.jpg');
      expect(await db.wishImagesOf(ownerA, wish.id), hasLength(1));
    });

    test('pending create отсутствует в snapshot → сохраняется', () async {
      api.failures['POST /wishes'] = 'network'; // create не ушёл
      final wish = await repo.createWish(title: 'Оффлайн');
      api.failures.remove('POST /wishes');
      await sync(); // pull: snapshot пуст, но у сущности pending create

      expect(await rowOf(wish.id), isNotNull);
      expect((await repo.getWishes()).single.title, 'Оффлайн');
    });

    test('pending update переживает snapshot со stale-версией', () async {
      final wish = await repo.createWish(title: 'Книга');
      await sync();
      await repo.updateWish(wish.copyWith(title: 'Локально новее'));
      api.failures['PATCH /wishes'] = 'network'; // update не ушёл
      await sync(); // pull видит старое серверное состояние

      expect((await rowOf(wish.id))!.title, 'Локально новее');
      expect((await outboxOf(ownerA)).single.operation, 'update');
    });

    test('failed pull не трогает локальные данные', () async {
      final wish = await repo.createWish(title: 'Книга');
      await sync();
      api.failures['GET /wishes'] = 500;
      api.deleteServerWish(ownerA, wish.id);
      await sync();
      expect(await rowOf(wish.id), isNotNull);
    });

    test('failed create отсутствует в snapshot → сущность сохранена', () async {
      api.failures['POST /wishes'] = 422;
      final wish = await repo.createWish(title: 'Не принято');
      await sync(); // push failed + pull прошёл — snapshot пуст

      expect((await outboxOf(ownerA)).single.status, 'failed');
      expect((await rowOf(wish.id))!.title, 'Не принято');
      expect(await repo.getWishes(), hasLength(1));
    });

    test(
      'failed update: snapshot со stale-данными не затирает локаль',
      () async {
        final wish = await repo.createWish(title: 'Книга');
        await sync();

        api.failures['PATCH /wishes'] = 422;
        await repo.updateWish(wish.copyWith(title: 'Локально новее'));
        await sync(); // push 422 → failed; pull вернул 'Книга'

        expect((await rowOf(wish.id))!.title, 'Локально новее');
        expect((await outboxOf(ownerA)).single.status, 'failed');
      },
    );

    test('snapshot применяется только к текущему owner_id', () async {
      // Локальная сущность другого аккаунта не должна затрагиваться.
      await db
          .into(db.wishes)
          .insert(
            WishesCompanion(
              id: const Value('b-wish'),
              ownerId: const Value(ownerB),
              title: const Value('Чужое'),
              createdAt: Value(DateTime.now()),
              updatedAt: Value(DateTime.now()),
            ),
          );

      await sync(); // snapshot ownerA пуст — 'b-wish' не трогаем.
      expect((await rowOf('b-wish'))!.ownerId, ownerB);
    });
  });

  group('account isolation', () {
    test('outbox аккаунта A не отправляется при attach(B)', () async {
      api.failures['POST /wishes'] = 'network'; // A создал offline
      await repo.createWish(title: 'Желание A');
      api.failures.clear();
      engine.detach();

      // «Вошёл» другой аккаунт — engine attached к B.
      engine.attach(ownerB);
      await sync();

      // Операция A не ушла на сервер под чужой сессией.
      expect(api.wishesOf(ownerA), isEmpty);
      expect((await outboxOf(ownerA)).single.operation, 'create');
    });
  });

  group('single-flight', () {
    test('конкурентные requestSync делят один прогон', () async {
      // Три «одновременных» вызова — один и тот же Future прогона.
      final f1 = engine.requestSync();
      final f2 = engine.requestSync();
      final f3 = engine.requestSync();
      expect(identical(f1, f2), isTrue);
      expect(identical(f2, f3), isTrue);
      await f3;

      // Все вызовы завершились, ни один запрос не пересёкся
      // с другим — прогоны строго последовательны.
      expect(api.maxInFlight, 1);
    });

    test('requestSync после завершения запускает новый прогон', () async {
      await repo.createWish(title: 'Книга');
      await sync(); // дождаться завершения (включая listener-triggered)
      api.requests.clear();

      await engine.requestSync();
      // Новый прогон состоялся (pull выполнен), outbox уже пуст.
      expect(api.requests, contains('GET /wishes'));
    });

    test('detach останавливает дальнейший push', () async {
      await repo.createWish(title: 'Книга');
      await sync(); // push завершён, outbox пуст
      engine.detach();
      api.requests.clear();

      // Детачнутый engine не выполняет ни push, ни pull.
      await engine.requestSync();
      expect(api.requests, isEmpty);
    });
  });

  group('auth expiration', () {
    test(
      '401 → повторная авторизация того же аккаунта возобновляет sync',
      () async {
        api.failures['POST /wishes'] = 401;
        final wish = await repo.createWish(title: 'Книга');
        await sync();
        expect(unauthorizedCalled, isTrue);
        expect((await outboxOf(ownerA)).single.status, 'pending');

        // Пользователь вошёл снова — session layer чистит credentials,
        // attach заново (тот же аккаунт) → sync продолжается.
        api.failures.clear();
        engine.attach(ownerA); // attach сбрасывает _authExpired
        await sync();

        expect(api.wishesOf(ownerA).single['title'], 'Книга');
        expect(await outboxOf(ownerA), isEmpty);
        expect((await rowOf(wish.id))!.title, 'Книга');
      },
    );

    test(
      'после 401 и очистки credentials старый токен не используется',
      () async {
        api.failures['POST /wishes'] = 401;
        await repo.createWish(title: 'Книга');
        await sync();
        expect(unauthorizedCalled, isTrue);

        // Session layer удалил токен из secure storage.
        const storage = FlutterSecureStorage();
        await storage.delete(key: 'access_token');
        api.failures.clear();

        // Пере-attach: запрос идёт без Bearer → fake отвечает 401 →
        // sync снова останавливается, локальные данные сохранены.
        engine.attach(ownerA);
        await sync();
        expect(unauthorizedCalled, isTrue);
        expect(api.wishesOf(ownerA), isEmpty);
        expect(await repo.getWishes(), hasLength(1));
      },
    );
  });

  group('cold start offline', () {
    test('persisted token + user_id + профиль = сессия без сети', () async {
      // Профиль в Drift — как после прошлого login.
      await db.upsertProfile(
        ProfilesCompanion(
          id: const Value(ownerA),
          email: const Value('a@chtohochu.ru'),
          name: const Value('A'),
          updatedAt: Value(DateTime.now()),
        ),
      );
      api.failures['GET /me'] = 'network'; // сети нет

      final auth = ApiAuthRepository(
        dio,
        SecureStorageService(const FlutterSecureStorage()),
        prefs,
        db,
      );
      final session = await auth.currentSession();

      expect(session, isNotNull);
      expect(session!.user.id, ownerA);
      expect(session.token, token);
      // Локальные желания доступны без сети.
      await repo.createWish(title: 'Оффлайн-желание');
      expect((await repo.getWishes()).single.title, 'Оффлайн-желание');
    });

    test(
      'нет persisted identity + offline → сессии нет, login нужен',
      () async {
        await prefs.clearCurrentUserId();
        api.failures['GET /me'] = 'network';

        final auth = ApiAuthRepository(
          dio,
          SecureStorageService(const FlutterSecureStorage()),
          prefs,
          db,
        );
        expect(await auth.currentSession(), isNull);
      },
    );
  });

  group('migration → sync', () {
    test('импортированные желания уходят на сервер при первом sync', () async {
      await SharedPreferences.getInstance().then(
        (p) => p.setString(
          'wishes_cache',
          '[{"id":"wish_1","title":"Из старой версии",'
              '"description":null,"price":null,"link":null,'
              '"imageUrl":null,"createdAt":"2025-01-01T00:00:00.000"}]',
        ),
      );
      await LegacyWishesMigration(db, prefs).migrate(ownerA);
      await sync();

      expect(api.wishesOf(ownerA).single['title'], 'Из старой версии');
      expect(await outboxOf(ownerA), isEmpty);
    });
  });

  group('stale response vs revived op', () {
    // PATCH в полёте → пользователь правит сущность → revive
    // переписывает op свежим payload. Ответ на СТАРЫЙ payload не
    // должен помечать/штрафовать/удалять свежее намерение.

    Future<Wish> seedWish() async {
      final wish = await repo.createWish(title: 'Книга');
      await sync(); // create доставлен
      api.requests.clear();
      return wish;
    }

    test(
      '422 на устаревший payload → свежая операция остаётся pending',
      () async {
        final wish = await seedWish();

        final gate = gated.hold('PATCH', '/wishes');
        await repo.updateWish(wish.copyWith(title: 'Битое обновление'));
        await gate.entered.future; // PATCH(bad) в полёте

        // Пользователь исправил значение, пока запрос был в полёте.
        await repo.updateWish(wish.copyWith(title: 'Хорошее обновление'));
        api.failuresOnce['PATCH /wishes'] = 422;
        gate.release();
        await sync();

        // Без fresh-check: markFailed хоронил бы revive'нутый op —
        // 'Хорошее' никогда бы не уехало.
        expect(api.wishesOf(ownerA).single['title'], 'Хорошее обновление');
        expect(await outboxOf(ownerA), isEmpty);
        expect((await rowOf(wish.id))!.title, 'Хорошее обновление');
      },
    );

    test('5xx на устаревший payload → свежей операции нет backoff', () async {
      final wish = await seedWish();

      final gate = gated.hold('PATCH', '/wishes');
      await repo.updateWish(wish.copyWith(title: 'Старое значение'));
      await gate.entered.future;

      await repo.updateWish(wish.copyWith(title: 'Новое значение'));
      api.failuresOnce['PATCH /wishes'] = 500;
      gate.release();
      await sync();

      // Без fresh-check: markRetry записал бы attempts старого
      // snapshot'а и отложил бы свежее намерение по backoff.
      expect(api.wishesOf(ownerA).single['title'], 'Новое значение');
      expect(await outboxOf(ownerA), isEmpty);
      expect((await rowOf(wish.id))!.title, 'Новое значение');
    });

    test('404 на устаревший PATCH не сносит сущность и свежий op', () async {
      final wish = await seedWish();

      final gate = gated.hold('PATCH', '/wishes');
      await repo.updateWish(wish.copyWith(title: 'Старое значение'));
      await gate.entered.future;

      await repo.updateWish(wish.copyWith(title: 'Новое значение'));
      api.failuresOnce['PATCH /wishes'] = 404;
      gate.release();
      await sync();

      // 404 про устаревшее намерение: сущность живёт, свежий op
      // доехал — remote-delete не «съедает» более новую правку.
      expect(await rowOf(wish.id), isNotNull);
      expect(api.wishesOf(ownerA).single['title'], 'Новое значение');
      expect(await outboxOf(ownerA), isEmpty);
    });

    test('409→GET 404 при переписанном payload не сносит сущность', () async {
      // create никогда не уезжал; сущности на сервере нет.
      final gate = gated.hold('POST', '/wishes');
      final wish = await repo.createWish(title: 'v1');
      await gate.entered.future; // POST(v1) в полёте

      // Пользователь изменил желание до ответа (create+update
      // compaction переписал payload того же op).
      await repo.updateWish(wish.copyWith(title: 'v2'));
      api.failuresOnce['POST /wishes'] = 409; // identity занята
      api.failuresOnce['GET /wishes/'] = 404; // reconcile-GET пуст
      gate.release();
      await sync();

      // Ответы про старое намерение: сущность и op живы;
      // повторный POST(v2) создаёт сущность на сервере.
      expect(await rowOf(wish.id), isNotNull);
      expect(api.wishesOf(ownerA).single['title'], 'v2');
      expect(await outboxOf(ownerA), isEmpty);
    });
  });

  group('media upload (ADR-015)', () {
    late Directory tmp;
    late List<String> puts;
    late SyncEngine mediaEngine;

    /// Presigned PUT: fake-put://{uploadId} → регистрируем объект
    /// в «object storage» fake-API, чтобы complete прошёл.
    SyncEngine buildEngine({bool failPutOnce = false}) {
      var failed = false;
      return SyncEngine(
        db: db,
        dio: dio,
        onUnauthorized: () {},
        onStatus: (_) {},
        mediaUploads: MediaUploadService(
          api: dio,
          put: (url, headers, file) async {
            if (failPutOnce && !failed) {
              failed = true;
              throw DioException(
                requestOptions: RequestOptions(),
                type: DioExceptionType.connectionError,
              );
            }
            puts.add(url);
            api.markMediaObjectPut(url);
          },
        ),
      );
    }

    Future<String> fakePhoto(String name) async {
      final file = File('${tmp.path}/$name.jpg');
      await file.writeAsBytes(List.filled(128, 7));
      return file.path;
    }

    setUp(() async {
      // Главный engine без media-фейка — отключаем, чтобы его
      // outbox-listener не дёргал реальный PUT.
      engine.detach();
      tmp = await Directory.systemTemp.createTemp('media_test');
      puts = [];
      mediaEngine = buildEngine()..attach(ownerA);
    });

    tearDown(() async {
      mediaEngine.detach();
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    test('primary + additional → uploaded, remote_url и локально, '
        'и на сервере', () async {
      final p1 = await fakePhoto('primary');
      final p2 = await fakePhoto('extra');
      final wish = await repo.createWish(
        title: 'Фото',
        imageUrl: p1,
        additionalImagePaths: [p2],
      );

      await mediaEngine.requestSync();

      final row = (await rowOf(wish.id))!;
      expect(row.imageUrl, startsWith('https://cdn.test/'));
      expect(row.imageUploadStatus, 'uploaded');
      final images = await db.wishImagesOf(ownerA, wish.id);
      expect(images.single.uploadStatus, 'uploaded');
      expect(images.single.remoteUrl, startsWith('https://cdn.test/'));
      // Primary remote_url дошёл до сервера штатным update-op.
      expect(
        api.wishesOf(ownerA).single['image_url'],
        startsWith('https://cdn.test/'),
      );
      expect(puts, hasLength(2));
      expect(
        api.requests.where((r) => r == 'POST /media/uploads'),
        hasLength(2),
      );
    });

    test('offline: upload откладывается, желание живёт', () async {
      api.failures['POST /media/uploads'] = 'network';
      final p = await fakePhoto('p');
      final wish = await repo.createWish(title: 'Оффлайн', imageUrl: p);

      await mediaEngine.requestSync();

      // Желание синхронизировано, фото осталось локальным pending.
      final row = (await rowOf(wish.id))!;
      expect(row.imageUrl, p);
      expect(row.imageUploadStatus, 'pending');
      expect(api.wishesOf(ownerA).single['title'], 'Оффлайн');

      // Сеть вернулась → следующий sync доставляет upload.
      api.failures.remove('POST /media/uploads');
      await mediaEngine.requestSync();

      final done = (await rowOf(wish.id))!;
      expect(done.imageUploadStatus, 'uploaded');
      expect(done.imageUrl, startsWith('https://cdn.test/'));
    });

    test('PUT retry идемпотентен: тот же upload, без дубликатов', () async {
      mediaEngine.detach();
      mediaEngine = buildEngine(failPutOnce: true)..attach(ownerA);
      final p = await fakePhoto('p');
      final wish = await repo.createWish(title: 'Ретрай', imageUrl: p);

      await mediaEngine.requestSync(); // PUT упал → pending

      expect((await rowOf(wish.id))!.imageUploadStatus, 'pending');

      await mediaEngine.requestSync(); // retry — успех

      expect((await rowOf(wish.id))!.imageUploadStatus, 'uploaded');
      // Инструкции запрашивались дважды, но server-side upload один:
      // client_id возвращает существующую запись и тот же object.
      final instructions = api.requests.where(
        (r) => r == 'POST /media/uploads',
      );
      expect(instructions, hasLength(2));
      final completes = api.requests.where(
        (r) => r.startsWith('POST /media/uploads/') && r.endsWith('/complete'),
      );
      expect(completes.toSet(), hasLength(1)); // один и тот же upload_id
    });

    test('4xx → failed: retry не повторяется, localPath на месте', () async {
      api.failures['POST /media/uploads'] = 422;
      final p = await fakePhoto('p');
      final wish = await repo.createWish(title: 'Брак', imageUrl: p);

      await mediaEngine.requestSync();
      await mediaEngine.requestSync(); // failed не выбирается повторно

      final row = (await rowOf(wish.id))!;
      expect(row.imageUploadStatus, 'failed');
      expect(row.imageUrl, p); // файл доступен локально
      expect(
        api.requests.where((r) => r == 'POST /media/uploads'),
        hasLength(1),
      );
    });

    test('pending create → media пропускается до push сущности', () async {
      api.failures['POST /wishes'] = 'network';
      final p = await fakePhoto('p');
      final wish = await repo.createWish(title: 'Ждёт', imageUrl: p);

      await mediaEngine.requestSync();

      // Create в backoff — сервер не знает сущность, media-фаза
      // пропускает upload (entity check вернул бы 404).
      expect(api.requests.where((r) => r.startsWith('POST /media/')), isEmpty);

      api.failures.remove('POST /wishes');
      // Новая локальная мутация revive'ит create-операцию (backoff сброшен).
      await OutboxStore(db).enqueue(
        ownerId: ownerA,
        entityType: 'wish',
        entityId: wish.id,
        operation: OutboxOp.update,
        payload: {'title': 'Ждёт'},
      );

      await mediaEngine.requestSync();
      expect(
        api.requests.where((r) => r == 'POST /media/uploads'),
        hasLength(1),
      );
    });

    test('remote image_url не вызывает media upload вообще', () async {
      final wish = await repo.createWish(
        title: 'Уже ссылка',
        imageUrl: 'https://cdn.example.com/x.jpg',
      );
      await mediaEngine.requestSync();

      expect(api.requests.where((r) => r.startsWith('POST /media/')), isEmpty);
      expect((await rowOf(wish.id))!.imageUploadStatus, 'uploaded');
    });

    test('потерянный файл → failed без бесконечного retry', () async {
      final wish = await repo.createWish(
        title: 'Нет файла',
        imageUrl: '${tmp.path}/ghost.jpg',
      );
      await mediaEngine.requestSync();
      await mediaEngine.requestSync();

      expect((await rowOf(wish.id))!.imageUploadStatus, 'failed');
    });
  });
}

/// Барьер для одного запроса: `entered` — запрос в полёте,
/// `release()` — отпустить на обработку fake API.
class _Gate {
  final entered = Completer<void>();
  final _release = Completer<void>();
  void release() => _release.complete();
}

/// Обёртка над [FakeApiAdapter], умеющая «держать» запросы,
/// совпадающие с ключом 'METHOD /path-prefix'.
class _GatedAdapter implements HttpClientAdapter {
  _GatedAdapter(this._inner);

  final FakeApiAdapter _inner;
  final _gates = <String, _Gate>{};

  _Gate hold(String method, String prefix) {
    final gate = _Gate();
    _gates['$method $prefix'] = gate;
    return gate;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    for (final entry in _gates.entries) {
      final parts = entry.key.split(' ');
      if (options.method == parts[0] && options.path.startsWith(parts[1])) {
        if (!entry.value.entered.isCompleted) {
          entry.value.entered.complete();
        }
        await entry.value._release.future;
        break;
      }
    }
    return _inner.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) => _inner.close(force: force);
}
