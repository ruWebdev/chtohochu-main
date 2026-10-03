import 'dart:async';

import 'package:chtohochu/core/database/app_database.dart';
import 'package:chtohochu/core/services/preferences_service.dart';
import 'package:chtohochu/core/services/secure_storage_service.dart';
import 'package:chtohochu/core/sync/sync_engine.dart';
import 'package:chtohochu/features/auth/data/auth_repository.dart';
import 'package:chtohochu/features/profile/data/profile_repository.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_api.dart';
import '../helpers/test_app.dart';

/// Offline-first Profile: `profiles` — source of truth,
/// мутации через общий outbox (entityType 'profile',
/// entityId = ownerId), push `PATCH /me`, pull `GET /me`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  const ownerA = 'user-a';
  const ownerB = 'user-b';

  late AppDatabase db;
  late FakeApiAdapter api;
  late _GatedAdapter gated;
  late SyncEngine engine;
  late DriftProfileRepository repo;
  late PreferencesService prefs;
  late bool unauthorizedCalled;

  Future<List<OutboxEntry>> outboxOf(String ownerId) {
    return (db.select(
      db.outboxEntries,
    )..where((o) => o.ownerId.equals(ownerId))).get();
  }

  Future<Profile?> rowOf(String id) => db.profileById(id);

  Future<void> sync() => engine.requestSync();

  List<String> mutatingRequests() =>
      api.requests.where((r) => !r.startsWith('GET')).toList();

  /// Детерминированный «оффлайн»: detach гасит outbox-listener,
  /// мутации копятся без автосинка; attach = reconnect.
  Future<void> offline(Future<void> Function() mutations) async {
    engine.detach();
    await mutations();
    engine.attach(ownerA);
  }

  /// Снять backoff у всех операций аккаунта (форсировать retry).
  Future<void> resetBackoff(String ownerId) async {
    await (db.update(db.outboxEntries)..where((o) => o.ownerId.equals(ownerId)))
        .write(const OutboxEntriesCompanion(nextRetryAt: Value(null)));
  }

  setUp(() async {
    setupTestStorage(
      preferences: {'current_user_id': ownerA},
      secureStorage: {'access_token': 'token-a'},
    );
    prefs = PreferencesService(await SharedPreferences.getInstance());
    db = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    repo = DriftProfileRepository(db, prefs);
    api = FakeApiAdapter(autoUserId: ownerA);
    gated = _GatedAdapter(api);
    final dio = createTestApiClient(gated);
    unauthorizedCalled = false;
    engine = SyncEngine(
      db: db,
      dio: dio,
      onUnauthorized: () => unauthorizedCalled = true,
      onStatus: (_) {},
    );
    // Строка profiles — как _persist при логине.
    await db.upsertProfile(
      const ProfilesCompanion(
        id: Value(ownerA),
        email: Value('user@chtohochu.ru'),
        name: Value('user'),
        username: Value('user'),
      ),
    );
    engine.attach(ownerA);
    await sync(); // стартовый pull: /me пишет server-представление
    api.requests.clear();
  });

  tearDown(() async {
    engine.detach();
    await db.close();
  });

  group('local', () {
    test('updateProfile пишет profiles + outbox атомарно', () async {
      await offline(
        () => repo.updateProfile(
          name: 'Николай',
          username: 'nikolay.k',
          avatarUrl: 'https://picsum.photos/seed/a/200',
        ),
      );

      final row = (await rowOf(ownerA))!;
      expect(row.name, 'Николай');
      expect(row.username, 'nikolay.k');
      expect(row.avatarUrl, 'https://picsum.photos/seed/a/200');
      expect(row.email, 'user@chtohochu.ru'); // email не меняется

      final op = (await outboxOf(ownerA)).single;
      expect(op.entityType, 'profile');
      expect(op.entityId, ownerA);
      expect(op.operation, 'update');
      expect(op.payloadJson, contains('"name":"Николай"'));
      expect(op.payloadJson, contains('"username":"nikolay.k"'));
      expect(
        op.payloadJson,
        contains('"avatar_url":"https://picsum.photos/seed/a/200"'),
      );
    });

    test('offline update сразу виден через watchProfile', () async {
      await offline(() => repo.updateProfile(name: 'Оффлайн'));

      expect((await repo.getProfile())!.name, 'Оффлайн');
      expect(await repo.watchProfile().first.then((u) => u!.name), 'Оффлайн');
    });

    test('username/avatar null очищают поля', () async {
      await offline(
        () => repo.updateProfile(
          name: 'Николай',
          username: 'nikk',
          avatarUrl: 'https://picsum.photos/seed/a/200',
        ),
      );
      await sync();

      await offline(() => repo.updateProfile(name: 'Николай'));
      final row = (await rowOf(ownerA))!;
      expect(row.username, isNull);
      expect(row.avatarUrl, isNull);
      final op = (await outboxOf(ownerA)).single;
      expect(op.payloadJson, contains('"username":null'));
      expect(op.payloadJson, contains('"avatar_url":null'));
    });
  });

  group('push', () {
    test('update → PATCH /me с финальным payload → reconcile', () async {
      await offline(
        () => repo.updateProfile(name: 'Николай', username: 'nikk'),
      );
      await sync();

      expect(mutatingRequests(), ['PATCH /me']);
      expect(await outboxOf(ownerA), isEmpty);
      expect(api.serverUser(ownerA)!['name'], 'Николай');
      expect(api.serverUser(ownerA)!['username'], 'nikk');
      // Локальная строка reconciled с ответом (server updated_at).
      final row = (await rowOf(ownerA))!;
      expect(row.name, 'Николай');
      expect(row.updatedAt, isNotNull);
    });

    test('update+update до sync → один PATCH с финальным payload', () async {
      await offline(() async {
        await repo.updateProfile(name: 'Первое');
        await repo.updateProfile(name: 'Второе', username: 'second');
      });
      api.requests.clear();
      await sync();

      expect(mutatingRequests(), ['PATCH /me']);
      expect(api.serverUser(ownerA)!['name'], 'Второе');
      expect(api.serverUser(ownerA)!['username'], 'second');
      expect(await outboxOf(ownerA), isEmpty);
    });
  });

  group('failures / retry / 401', () {
    test(
      '422 (username занят) → op failed, локальные данные сохранены',
      () async {
        api.seedUser('u9', name: 'Чужой', username: 'taken');
        await offline(
          () => repo.updateProfile(name: 'Николай', username: 'taken'),
        );

        await sync();

        final op = (await outboxOf(ownerA)).single;
        expect(op.status, 'failed');
        expect(op.lastError, isNotNull);
        // Локальная правка не потеряна — UI показывает её.
        expect((await rowOf(ownerA))!.username, 'taken');
        // Сервер отказал — его состояние не изменилось.
        expect(api.serverUser(ownerA)!['username'], 'user');
      },
    );

    test(
      '422 → edit again → failed revive в pending → sync доезжает',
      () async {
        api.seedUser('u9', name: 'Чужой', username: 'taken');
        await offline(
          () => repo.updateProfile(name: 'Николай', username: 'taken'),
        );
        await sync();
        expect((await outboxOf(ownerA)).single.status, 'failed');

        // Пользователь исправил username — операция снова pending.
        await repo.updateProfile(name: 'Николай', username: 'nikk');
        final op = (await outboxOf(ownerA)).single;
        expect(op.operation, 'update');
        expect(op.status, 'pending');
        expect(op.attempts, 0);

        await sync();
        expect(api.serverUser(ownerA)!['username'], 'nikk');
        expect(await outboxOf(ownerA), isEmpty);
      },
    );

    test(
      '5xx на PATCH → retry с backoff, локальные данные сохранены',
      () async {
        api.failures['PATCH /me'] = 500;
        await offline(() => repo.updateProfile(name: 'Retry'));
        await sync();

        var op = (await outboxOf(ownerA)).single;
        expect(op.status, 'pending');
        expect(op.attempts, greaterThan(0));
        expect(api.serverUser(ownerA)!['name'], 'user'); // не доехало

        api.failures.clear();
        await resetBackoff(ownerA);
        await sync();

        expect(api.serverUser(ownerA)!['name'], 'Retry');
        expect(await outboxOf(ownerA), isEmpty);
      },
    );

    test('401 на PATCH → auth-expired flow, op сохранён', () async {
      api.failures['PATCH /me'] = 401;
      await offline(() => repo.updateProfile(name: 'Noauth'));

      await sync();

      expect(unauthorizedCalled, isTrue);
      expect(await outboxOf(ownerA), isNotEmpty);

      // Reattach с «новым» токеном — доставка возобновляется.
      api.failures.clear();
      engine.attach(ownerA);
      await sync();

      expect(api.serverUser(ownerA)!['name'], 'Noauth');
      expect(await outboxOf(ownerA), isEmpty);
    });

    test('404 на PATCH /me → op failed, профиль НЕ удалён', () async {
      api.failures['PATCH /me'] = 404;
      await offline(() => repo.updateProfile(name: 'Ghost'));
      await sync();

      final op = (await outboxOf(ownerA)).single;
      expect(op.status, 'failed');
      // Profile — session identity, dropLocalEntity недопустим.
      final row = (await rowOf(ownerA))!;
      expect(row.name, 'Ghost');
    });
  });

  group('mid-flight mutations', () {
    test('PATCH в полёте + вторая правка → ответ A не затирает B', () async {
      final gate = gated.hold('PATCH', '/me');
      await repo.updateProfile(name: 'A');
      await gate.entered.future; // PATCH(payload A) летит

      // Пользователь снова изменил профиль, пока запрос в полёте.
      await repo.updateProfile(name: 'B', username: 'b_name');
      gate.release();
      await sync();

      // Ответ A не затёр B: converge перезаписал op payload'ом B,
      // тот же прогон доставил его. Финальная сходимость — B.
      expect(api.serverUser(ownerA)!['name'], 'B');
      expect(api.serverUser(ownerA)!['username'], 'b_name');
      expect(await outboxOf(ownerA), isEmpty);
      expect((await rowOf(ownerA))!.name, 'B');
    });
  });

  group('pull /me', () {
    test('remote изменение профиля → reconcile обновляет строку', () async {
      api.updateServerUser(ownerA, {
        'name': 'Серверное имя',
        'username': 'server_name',
      });

      await sync();

      final row = (await rowOf(ownerA))!;
      expect(row.name, 'Серверное имя');
      expect(row.username, 'server_name');
    });

    test('pending profile op защищён от snapshot — local wins', () async {
      api.failures['PATCH /me'] = 500;
      await offline(() => repo.updateProfile(name: 'Локальная правка'));
      // Remote изменение пришло «с другого устройства».
      api.updateServerUser(ownerA, {'name': 'Remote'});

      await sync(); // push 500 → backoff; pull защищает pending

      expect((await rowOf(ownerA))!.name, 'Локальная правка');
      expect(await outboxOf(ownerA), isNotEmpty);
    });

    test('failed profile op защищён от snapshot — local wins', () async {
      api.seedUser('u9', name: 'Чужой', username: 'taken');
      await offline(
        () => repo.updateProfile(name: 'Моё имя', username: 'taken'),
      );
      await sync();
      expect((await outboxOf(ownerA)).single.status, 'failed');

      api.failures.clear();
      api.updateServerUser(ownerA, {'name': 'Remote'});
      await sync();

      expect((await rowOf(ownerA))!.name, 'Моё имя');
      expect((await outboxOf(ownerA)).single.status, 'failed');
    });

    test('malformed /me → reconcile не выполняется, данных нет', () async {
      final broken = _MalformedAdapter(api);
      final brokenDio = createTestApiClient(broken);
      final brokenEngine = SyncEngine(
        db: db,
        dio: brokenDio,
        onUnauthorized: () => unauthorizedCalled = true,
        onStatus: (_) {},
      );
      brokenEngine.attach(ownerA);

      // Remote-изменения, которые не должны примениться.
      api.seedWish(ownerA, {
        'id': 'srv-w1',
        'title': 'Не должно появиться',
        'description': null,
        'price': null,
        'link': null,
        'image_url': null,
        'created_at': '2026-01-01T00:00:00.000Z',
        'updated_at': '2026-01-01T00:00:00.000Z',
      });
      api.updateServerUser(ownerA, {'name': 'Remote'});

      await brokenEngine.requestSync();

      // Snapshot не применился атомарно: ни wishes, ни профиль.
      expect(
        await (db.select(
          db.wishes,
        )..where((w) => w.id.equals('srv-w1'))).getSingleOrNull(),
        isNull,
      );
      expect((await rowOf(ownerA))!.name, 'user');
      brokenEngine.detach();
    });
  });

  group('account switch / stale responses', () {
    test('pending op A не отправляется при attach(B)', () async {
      engine.detach();
      await repo.updateProfile(name: 'A-name');

      engine.attach(ownerB);
      await sync();

      // Ни одного PATCH — операция A остаётся pending.
      expect(mutatingRequests(), isEmpty);
      expect(await outboxOf(ownerA), isNotEmpty);
    });

    test(
      'in-flight PATCH A + logout/clear + attach(B) → ответ не пишет',
      () async {
        final gate = gated.hold('PATCH', '/me');
        await repo.updateProfile(name: 'A-flight');
        await gate.entered.future; // PATCH в полёте

        final run = engine.requestSync();
        engine.detach();
        await db.clearAccountData(ownerA); // logout-очистка
        engine.attach(ownerB);
        gate.release();
        await run;

        // Ответ A не воскресил вычищенный профиль, op не завершена
        // «успехом» постороннего ответа (операция удалена clear-ом).
        expect(await rowOf(ownerA), isNull);
        expect(await outboxOf(ownerA), isEmpty);
      },
    );

    test('in-flight 401 аккаунта A не сносит сессию B', () async {
      final gate = gated.hold('PATCH', '/me');
      await repo.updateProfile(name: 'A-flight');
      await gate.entered.future;

      final run = engine.requestSync();
      engine.detach();
      engine.attach(ownerB);
      api.failures['PATCH /me'] = 401;
      gate.release();
      await run;

      // Чужой 401 — не auth-expired нового аккаунта.
      expect(unauthorizedCalled, isFalse);
      // Операция A осталась pending — не помечена failed чужим ответом.
      final op = (await outboxOf(ownerA)).single;
      expect(op.status, 'pending');
    });

    test('snapshot /me в полёте + detach → reconcile не пишет', () async {
      api.updateServerUser(ownerA, {'name': 'Remote'});
      final gate = gated.hold('GET', '/me');
      final run = sync();
      await gate.entered.future;

      engine.detach();
      gate.release();
      await run;

      expect((await rowOf(ownerA))!.name, 'user'); // remote не применился
    });
  });

  group('legacy user_profile_cache migration', () {
    test(
      'merge ставит pending update — pull не затирает перенесённые значения',
      () async {
        // Pre-Drift правка: legacy-кэш новее сервера. Миграция обязана
        // перенести значения И поставить outbox op — иначе ближайший
        // GET /me reconcile вернёт строку к серверному состоянию.
        await prefs.writeUserProfileCache(
          '{"name":"Мария","username":"maria.k","avatarUrl":null}',
        );
        final auth = ApiAuthRepository(
          createTestApiClient(api),
          SecureStorageService(const FlutterSecureStorage()),
          prefs,
          db,
        );

        final session = await auth.currentSession();
        expect(session!.user.name, 'Мария');
        expect(session.user.username, 'maria.k');
        expect(prefs.readUserProfileCache(), isNull); // кэш очищен

        final op = (await outboxOf(ownerA)).single;
        expect(op.entityType, 'profile');
        expect(op.operation, 'update');
        expect(op.payloadJson, contains('"name":"Мария"'));

        // Sync доставляет перенесённые значения; pull идемпотентен.
        await sync();
        expect(api.serverUser(ownerA)!['name'], 'Мария');
        expect(api.serverUser(ownerA)!['username'], 'maria.k');
        expect(await outboxOf(ownerA), isEmpty);
        expect((await rowOf(ownerA))!.name, 'Мария');
      },
    );

    test('cache без отличий от сервера не создаёт outbox op', () async {
      // setUp-seeded строка совпадает с serverUser (user/user) —
      // legacy-кэш с теми же значениями: merge без outbox op.
      await prefs.writeUserProfileCache(
        '{"name":"user","username":"user","avatarUrl":null}',
      );
      final auth = ApiAuthRepository(
        createTestApiClient(api),
        SecureStorageService(const FlutterSecureStorage()),
        prefs,
        db,
      );

      await auth.currentSession();
      expect(await outboxOf(ownerA), isEmpty);
      expect(prefs.readUserProfileCache(), isNull);
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

/// Adapter, возвращающий malformed-ответ на `GET /me`
/// (data — не объект) — остальное проксирует в fake API.
class _MalformedAdapter implements HttpClientAdapter {
  _MalformedAdapter(this._inner);

  final FakeApiAdapter _inner;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'GET' && options.path == '/me') {
      return ResponseBody.fromString(
        '{"data": [1,2,3]}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    return _inner.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) => _inner.close(force: force);
}
