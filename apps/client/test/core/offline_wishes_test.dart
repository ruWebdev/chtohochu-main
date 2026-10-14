import 'dart:convert';

import 'package:chtohochu/core/database/app_database.dart';
import 'package:chtohochu/core/database/legacy_migration.dart';
import 'package:chtohochu/core/services/preferences_service.dart';
import 'package:chtohochu/core/sync/outbox_store.dart';
import 'package:chtohochu/features/wishes/data/wish_repository.dart';
import 'package:chtohochu/features/wishes/domain/wish.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Offline-first Wishes: Drift как source of truth, UUID identity,
/// атомарность мутация+outbox, compaction, account isolation,
/// реактивный watch, миграция legacy-кэша.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  const ownerA = 'user-a';
  const ownerB = 'user-b';

  late AppDatabase db;
  late SharedPreferences prefs;
  late DriftWishRepository repo;

  Future<void> setOwner(String ownerId) async {
    await prefs.setString('current_user_id', ownerId);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({'current_user_id': ownerA});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    repo = DriftWishRepository(db, PreferencesService(prefs));
  });

  tearDown(() async => db.close());

  Future<List<OutboxEntry>> outboxOf(String ownerId) {
    return (db.select(
      db.outboxEntries,
    )..where((o) => o.ownerId.equals(ownerId))).get();
  }

  Future<WishRow?> rowOf(String id) =>
      (db.select(db.wishes)..where((w) => w.id.equals(id))).getSingleOrNull();

  final uuidRe = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  group('Drift CRUD + outbox atomicity', () {
    test(
      'create: wish + outbox(create) атомарно, id — клиентский UUID',
      () async {
        final wish = await repo.createWish(title: 'Книга', price: 500);

        expect(uuidRe.hasMatch(wish.id), isTrue);
        expect((await repo.getWishes()).single.id, wish.id);

        final ops = await outboxOf(ownerA);
        expect(ops.single.operation, 'create');
        expect(ops.single.entityId, wish.id);
        final payload = jsonDecode(ops.single.payloadJson!) as Map;
        expect(payload['id'], wish.id);
        expect(payload['title'], 'Книга');
      },
    );

    test('update: строка обновлена, updatedAt изменён', () async {
      final wish = await repo.createWish(title: 'Книга');
      final updated = await repo.updateWish(
        wish.copyWith(title: 'Книга (вторая редакция)'),
      );

      final row = (await rowOf(wish.id))!;
      expect(row.title, 'Книга (вторая редакция)');
      expect(updated.updatedAt, isNot(wish.updatedAt));
    });

    test('delete чистого желания: tombstone + outbox(delete)', () async {
      final wish = await repo.createWish(title: 'Книга');
      // Имитация «уже синхронизировано»: снять create-операцию.
      for (final op in await outboxOf(ownerA)) {
        await (db.delete(
          db.outboxEntries,
        )..where((o) => o.id.equals(op.id))).go();
      }

      await repo.deleteWish(wish.id);

      final row = (await rowOf(wish.id))!;
      expect(row.deletedAt, isNotNull);
      // UI не видит tombstone.
      expect(await repo.getWishes(), isEmpty);
      expect(await repo.hasWishes(), isFalse);

      final ops = await outboxOf(ownerA);
      expect(ops.single.operation, 'delete');
      expect(ops.single.entityId, wish.id);
    });

    test('getWishById возвращает null после tombstone-delete', () async {
      final wish = await repo.createWish(title: 'Книга');
      await repo.deleteWish(wish.id);
      expect(await repo.getWishById(wish.id), isNull);
    });
  });

  group('Wish priority', () {
    test('create по умолчанию → normal, payload несёт поле', () async {
      final wish = await repo.createWish(title: 'Книга');

      expect(wish.priority, WishPriority.normal);
      expect((await rowOf(wish.id))!.priority, 'normal');

      final ops = await outboxOf(ownerA);
      expect(
        (jsonDecode(ops.single.payloadJson!) as Map)['priority'],
        'normal',
      );
    });

    test('create с каждым уровнем персистится', () async {
      for (final p in WishPriority.values) {
        final wish = await repo.createWish(
          title: 'Желание ${p.name}',
          priority: p,
        );
        expect((await rowOf(wish.id))!.priority, p.name);
        expect((await repo.getWishById(wish.id))!.priority, p);
      }
    });

    test('update меняет priority, payload update несёт поле', () async {
      final wish = await repo.createWish(
        title: 'Книга',
        priority: WishPriority.later,
      );

      await repo.updateWish(wish.copyWith(priority: WishPriority.high));

      expect((await rowOf(wish.id))!.priority, 'high');
      // create+update схлопнулись в один create с финальным payload.
      final ops = await outboxOf(ownerA);
      expect(ops.single.operation, 'create');
      expect((jsonDecode(ops.single.payloadJson!) as Map)['priority'], 'high');
    });

    test('assignWishToList сохраняет priority', () async {
      final wish = await repo.createWish(
        title: 'Книга',
        priority: WishPriority.high,
      );
      final list = await repo.createWishList(title: 'Подарки');

      await repo.assignWishToList(wish.id, list.id);

      final row = (await rowOf(wish.id))!;
      expect(row.listId, list.id);
      expect(row.priority, 'high');
    });
  });

  group('Outbox compaction', () {
    test('create + update → один create с финальным payload', () async {
      final wish = await repo.createWish(title: 'Книга');
      await repo.updateWish(wish.copyWith(title: 'Новая книга'));

      final ops = await outboxOf(ownerA);
      expect(ops, hasLength(1));
      expect(ops.single.operation, 'create');
      expect(
        (jsonDecode(ops.single.payloadJson!) as Map)['title'],
        'Новая книга',
      );
    });

    test('create + delete → нет ни сущности, ни операций', () async {
      final wish = await repo.createWish(title: 'Книга');
      await repo.deleteWish(wish.id);

      expect(await rowOf(wish.id), isNull);
      expect(await outboxOf(ownerA), isEmpty);
    });

    test('update + update → один update', () async {
      final wish = await repo.createWish(title: 'Книга');
      // «Синхронизировано»: outbox пуст.
      for (final op in await outboxOf(ownerA)) {
        await (db.delete(
          db.outboxEntries,
        )..where((o) => o.id.equals(op.id))).go();
      }

      await repo.updateWish(wish.copyWith(title: 'v2'));
      await repo.updateWish(wish.copyWith(title: 'v3'));

      final ops = await outboxOf(ownerA);
      expect(ops, hasLength(1));
      expect(ops.single.operation, 'update');
      expect((jsonDecode(ops.single.payloadJson!) as Map)['title'], 'v3');
    });

    test('update + delete → только delete', () async {
      final wish = await repo.createWish(title: 'Книга');
      for (final op in await outboxOf(ownerA)) {
        await (db.delete(
          db.outboxEntries,
        )..where((o) => o.id.equals(op.id))).go();
      }

      await repo.updateWish(wish.copyWith(title: 'v2'));
      await repo.deleteWish(wish.id);

      final ops = await outboxOf(ownerA);
      expect(ops, hasLength(1));
      expect(ops.single.operation, 'delete');
    });
  });

  group('Transaction atomicity', () {
    test('провал транзакции не оставляет wish без outbox', () async {
      try {
        await db.transaction(() async {
          await db
              .into(db.wishes)
              .insert(
                WishesCompanion(
                  id: const Value('w-tx'),
                  ownerId: const Value(ownerA),
                  title: const Value('Tx'),
                  createdAt: Value(DateTime.now()),
                  updatedAt: Value(DateTime.now()),
                ),
              );
          throw StateError('boom');
        });
      } on StateError {
        // expected — транзакция откатилась.
      }

      expect(await rowOf('w-tx'), isNull);
      expect(await outboxOf(ownerA), isEmpty);
    });
  });

  group('Account isolation', () {
    test('wishes и outbox scope’нуты по owner_id', () async {
      await repo.createWish(title: 'Желание A');
      await setOwner(ownerB);
      await repo.createWish(title: 'Желание B');

      expect((await repo.getWishes()).map((w) => w.title), ['Желание B']);
      expect(
        (await outboxOf(ownerB)).map((o) => o.entityId),
        isNot(contains((await outboxOf(ownerA)).first.entityId)),
      );
    });

    test('repositories без current_user_id не читают данные', () async {
      await prefs.remove('current_user_id');
      expect(() => repo.getWishes(), throwsA(isA<WishError>()));
    });
  });

  group('Reactive watch', () {
    test('watchWishes эмитит при локальной мутации', () async {
      // Первое событие — текущее состояние (пусто).
      expect(await repo.watchWishes().first, isEmpty);

      // Локальная мутация → новое событие со свежим списком.
      await repo.createWish(title: 'Книга');
      final updated = await repo.watchWishes().firstWhere(
        (list) => list.isNotEmpty,
      );
      expect(updated.single.title, 'Книга');
    });
  });

  group('Legacy wishes_cache migration', () {
    test('импортирует в Drift с UUID + outbox, идемпотентна', () async {
      await prefs.setString(
        'wishes_cache',
        '[{"id":"wish_1700000000000","title":"Старая книга",'
            '"description":null,"price":300,"link":null,"imageUrl":null,'
            '"createdAt":"2025-01-01T00:00:00.000"}]',
      );
      final migration = LegacyWishesMigration(db, PreferencesService(prefs));

      await migration.migrate(ownerA);

      final wishes = await repo.getWishes();
      expect(wishes.single.title, 'Старая книга');
      // Старый `wish_<millis>` id — не UUID → новый UUID выдан.
      expect(uuidRe.hasMatch(wishes.single.id), isTrue);
      // Импортированное желание — pending create (уедет при sync).
      expect((await outboxOf(ownerA)).single.operation, 'create');
      // Legacy-кэш очищен, флаг выставлен.
      expect(prefs.getString('wishes_cache'), isNull);
      expect(prefs.getBool('wishes_migrated'), isTrue);

      // Повторный запуск — no-op, дублей нет.
      await migration.migrate(ownerA);
      expect(await repo.getWishes(), hasLength(1));
    });

    test('валидный UUID сохраняется как identity', () async {
      const uuid = '550e8400-e29b-41d4-a716-446655440000';
      await prefs.setString(
        'wishes_cache',
        '[{"id":"$uuid","title":"Уже UUID","description":null,'
            '"price":null,"link":null,"imageUrl":null,'
            '"createdAt":"2025-01-01T00:00:00.000"}]',
      );
      await LegacyWishesMigration(
        db,
        PreferencesService(prefs),
      ).migrate(ownerA);

      expect((await repo.getWishes()).single.id, uuid);
    });
  });

  group('Wish images (local storage)', () {
    test('create: image_url = primary, additional → wish_images '
        'с sort_order и owner-scope', () async {
      final wish = await repo.createWish(
        title: 'Дрель',
        imageUrl: '/tmp/photo-0.jpg',
        additionalImagePaths: ['/tmp/photo-1.jpg', '/tmp/photo-2.jpg'],
      );

      expect((await rowOf(wish.id))!.imageUrl, '/tmp/photo-0.jpg');

      final rows = await db.wishImagesOf(ownerA, wish.id);
      expect(rows.map((r) => r.localPath), [
        '/tmp/photo-1.jpg',
        '/tmp/photo-2.jpg',
      ]);
      expect(rows.map((r) => r.sortOrder), [1, 2]);
      for (final r in rows) {
        expect(r.ownerId, ownerA);
        expect(r.remoteUrl, isNull);
        expect(r.wishId, wish.id);
      }
    });

    test('watchWishImages стримит доменные сущности по sort_order', () async {
      final wish = await repo.createWish(
        title: 'Дрель',
        additionalImagePaths: ['/tmp/b.jpg', '/tmp/a.jpg'],
      );

      final images = await repo.watchWishImages(wish.id).first;
      expect(images.map((i) => i.localPath), ['/tmp/b.jpg', '/tmp/a.jpg']);
      expect(images.map((i) => i.displaySource), ['/tmp/b.jpg', '/tmp/a.jpg']);
    });

    test('create без additional → wish_images пуст', () async {
      final wish = await repo.createWish(title: 'Текст');
      expect(await db.wishImagesOf(ownerA, wish.id), isEmpty);
    });

    test('imageDisplaySource: remote_url после upload не вытесняет '
        'локальный файл (нет flicker)', () async {
      final wish = await repo.createWish(
        title: 'Дрель',
        imageUrl: '/tmp/photo-0.jpg',
      );
      expect(wish.imageDisplaySource, '/tmp/photo-0.jpg');
      expect((await rowOf(wish.id))!.imageLocalPath, '/tmp/photo-0.jpg');

      // Media upload завершён: sync пишет remote URL в image_url
      // (server-facing поле), локальный путь не трогает.
      await db.setWishImageUploadState(
        ownerA,
        wish.id,
        status: 'uploaded',
        remoteUrl: 'https://cdn.test/img.png',
      );

      final row = (await rowOf(wish.id))!;
      expect(row.imageUrl, 'https://cdn.test/img.png');
      expect(row.imageLocalPath, '/tmp/photo-0.jpg');

      final domain = (await repo.getWishById(wish.id))!;
      expect(domain.imageUrl, 'https://cdn.test/img.png');
      // Инвариант: источник отображения не переключается — UI
      // продолжает показывать тот же локальный файл.
      expect(domain.imageDisplaySource, '/tmp/photo-0.jpg');
    });

    test('updateWish: remote image_url после upload сохраняет '
        'image_local_path при правке других полей', () async {
      final wish = await repo.createWish(
        title: 'Дрель',
        imageUrl: '/tmp/photo-0.jpg',
      );
      await db.setWishImageUploadState(
        ownerA,
        wish.id,
        status: 'uploaded',
        remoteUrl: 'https://cdn.test/img.png',
      );

      final stored = (await repo.getWishById(wish.id))!;
      await repo.updateWish(stored.copyWith(title: 'Дрель+'));

      final row = (await rowOf(wish.id))!;
      expect(row.imageLocalPath, '/tmp/photo-0.jpg');
      expect(
        (await repo.getWishById(wish.id))!.imageDisplaySource,
        '/tmp/photo-0.jpg',
      );
    });

    test('updateWish: смена image_url с локального на URL сбрасывает '
        'image_local_path', () async {
      final wish = await repo.createWish(
        title: 'Дрель',
        imageUrl: '/tmp/photo-0.jpg',
      );
      final stored = (await repo.getWishById(wish.id))!;
      await repo.updateWish(
        Wish(
          id: stored.id,
          title: stored.title,
          createdAt: stored.createdAt,
          imageUrl: 'https://cdn.test/new.png',
        ),
      );

      final row = (await rowOf(wish.id))!;
      expect(row.imageLocalPath, isNull);
      expect(
        (await repo.getWishById(wish.id))!.imageDisplaySource,
        'https://cdn.test/new.png',
      );
    });

    test('outbox payload не несёт локальные пути ни в image_url, '
        'ни где-либо ещё', () async {
      await repo.createWish(
        title: 'Фото',
        imageUrl: '/tmp/local.jpg',
        additionalImagePaths: ['/tmp/extra.jpg'],
      );
      final payload =
          jsonDecode((await outboxOf(ownerA)).single.payloadJson!) as Map;
      // Локальный файл — не remote URL → в API не отправляется.
      expect(payload['image_url'], isNull);
      expect(payload.toString(), isNot(contains('/tmp/')));
    });

    test('remote image_url по-прежнему уходит в payload', () async {
      await repo.createWish(
        title: 'Ссылка на картинку',
        imageUrl: 'https://cdn.example.com/x.jpg',
      );
      final payload =
          jsonDecode((await outboxOf(ownerA)).single.payloadJson!) as Map;
      expect(payload['image_url'], 'https://cdn.example.com/x.jpg');
    });

    test('deleteWish unsynced create: wish_images уходят каскадно', () async {
      final wish = await repo.createWish(
        title: 'Фото',
        additionalImagePaths: ['/tmp/x.jpg'],
      );
      expect(await db.wishImagesOf(ownerA, wish.id), hasLength(1));

      await repo.deleteWish(wish.id);

      expect(await rowOf(wish.id), isNull);
      expect(await db.wishImagesOf(ownerA, wish.id), isEmpty);
    });

    test('tombstone delete: изображения живут до confirm DELETE', () async {
      final wish = await repo.createWish(
        title: 'Фото',
        additionalImagePaths: ['/tmp/x.jpg'],
      );
      // Снимаем create-op — сущность ведёт себя как синхронизированная.
      await (db.delete(
        db.outboxEntries,
      )..where((o) => o.ownerId.equals(ownerA))).go();

      await repo.deleteWish(wish.id);

      // Tombstone-строка скрыта, но при 422 на DELETE желание
      // вернётся — фото должны пережить tombstone.
      expect(await db.wishImagesOf(ownerA, wish.id), hasLength(1));
    });
  });

  group('Wish images (edit)', () {
    Future<List<WishImageRow>> imagesOf(String wishId) =>
        db.wishImagesOf(ownerA, wishId);

    /// Снимает outbox-операции — имитация «уже синхронизировано».
    Future<void> markSynced() => (db.delete(
      db.outboxEntries,
    )..where((o) => o.ownerId.equals(ownerA))).go();

    test('newFile → новые pending-строки с sort_order 1..N, '
        'uploadId == id (client_id для server cleanup)', () async {
      final wish = await repo.createWish(title: 'Фото');
      await markSynced();

      await repo.updateWish(
        wish,
        images: const [
          WishImageInput.newFile('/tmp/a.jpg'),
          WishImageInput.newFile('/tmp/b.jpg'),
        ],
      );

      final rows = await imagesOf(wish.id);
      expect(rows.map((r) => r.localPath), ['/tmp/a.jpg', '/tmp/b.jpg']);
      expect(rows.map((r) => r.sortOrder), [1, 2]);
      for (final r in rows) {
        expect(r.uploadStatus, 'pending');
        expect(r.uploadId, r.id);
        expect(r.remoteUrl, isNull);
      }
      // Локальные пути в outbox payload не уходят — там только
      // remote-набор (пока пуст).
      final payload =
          jsonDecode((await outboxOf(ownerA)).single.payloadJson!) as Map;
      expect(payload['images'], isEmpty);
    });

    test(
      'existing → строка сохраняется; порядок списка → sort_order',
      () async {
        final wish = await repo.createWish(
          title: 'Фото',
          additionalImagePaths: ['/tmp/a.jpg', '/tmp/b.jpg'],
        );
        await markSynced();
        final current = await imagesOf(wish.id);
        final (a, b) = (current[0], current[1]);

        // Перевёрнутый порядок: b первым.
        await repo.updateWish(
          wish,
          images: [
            WishImageInput.existing(b.id),
            WishImageInput.existing(a.id),
          ],
        );

        final rows = await imagesOf(wish.id);
        expect(rows.map((r) => r.id), [b.id, a.id]);
        expect(rows.map((r) => r.sortOrder), [1, 2]);
      },
    );

    test('отсутствующие в наборе строки удаляются; пустой список '
        'чищает всё', () async {
      final wish = await repo.createWish(
        title: 'Фото',
        additionalImagePaths: ['/tmp/a.jpg', '/tmp/b.jpg'],
      );
      await markSynced();

      await repo.updateWish(wish, images: const []);
      expect(await imagesOf(wish.id), isEmpty);
    });

    test('payload images содержит только remote-строки {id,url}', () async {
      final wish = await repo.createWish(
        title: 'Фото',
        additionalImagePaths: ['/tmp/a.jpg', '/tmp/b.jpg'],
      );
      await markSynced();
      final current = await imagesOf(wish.id);
      // a загружено (remote), b ещё pending.
      await db.setWishImageRowUploadState(
        ownerA,
        current[0].id,
        status: 'uploaded',
        remoteUrl: 'https://cdn.test/a.jpg',
      );

      await repo.updateWish(
        wish,
        images: [
          WishImageInput.existing(current[0].id),
          WishImageInput.existing(current[1].id),
        ],
      );

      final payload =
          jsonDecode((await outboxOf(ownerA)).single.payloadJson!) as Map;
      expect(payload['images'], [
        {'id': current[0].id, 'url': 'https://cdn.test/a.jpg'},
      ]);
    });

    test(
      'updateWish без images → payload несёт текущий remote-набор',
      () async {
        final wish = await repo.createWish(
          title: 'Фото',
          additionalImagePaths: ['/tmp/a.jpg'],
        );
        await markSynced();
        final row = (await imagesOf(wish.id)).single;
        await db.setWishImageRowUploadState(
          ownerA,
          row.id,
          status: 'uploaded',
          remoteUrl: 'https://cdn.test/a.jpg',
        );

        await repo.updateWish(wish.copyWith(title: 'Другое'));

        final payload =
            jsonDecode((await outboxOf(ownerA)).single.payloadJson!) as Map;
        expect(payload['title'], 'Другое');
        expect(payload['images'], [
          {'id': row.id, 'url': 'https://cdn.test/a.jpg'},
        ]);
      },
    );

    test('новый primary-файл → imageUploadStatus pending + uploadId', () async {
      final wish = await repo.createWish(
        title: 'Фото',
        imageUrl: 'https://cdn.test/old.jpg',
      );
      await markSynced();

      await repo.updateWish(
        Wish(
          id: wish.id,
          title: wish.title,
          createdAt: wish.createdAt,
          imageUrl: '/tmp/new-primary.jpg',
        ),
      );

      final row = (await rowOf(wish.id))!;
      expect(row.imageUrl, '/tmp/new-primary.jpg');
      expect(row.imageLocalPath, '/tmp/new-primary.jpg');
      expect(row.imageUploadStatus, 'pending');
      expect(row.imageUploadId, isNotNull);
      // Локальный путь не уходит в API.
      final payload =
          jsonDecode((await outboxOf(ownerA)).single.payloadJson!) as Map;
      expect(payload['image_url'], isNull);
    });

    test('продвижение additional→primary: remote URL переходит в '
        'image_url, строка удаляется', () async {
      final wish = await repo.createWish(
        title: 'Фото',
        imageUrl: 'https://cdn.test/old.jpg',
        additionalImagePaths: ['/tmp/promoted.jpg'],
      );
      await markSynced();
      final img = (await imagesOf(wish.id)).single;
      await db.setWishImageRowUploadState(
        ownerA,
        img.id,
        status: 'uploaded',
        remoteUrl: 'https://cdn.test/promoted.jpg',
      );

      // Форма: первый фото = бывший additional (remote), additional
      // набор пуст.
      await repo.updateWish(
        Wish(
          id: wish.id,
          title: wish.title,
          createdAt: wish.createdAt,
          imageUrl: 'https://cdn.test/promoted.jpg',
        ),
        images: const [],
      );

      expect((await rowOf(wish.id))!.imageUrl, 'https://cdn.test/promoted.jpg');
      expect(await imagesOf(wish.id), isEmpty);
      final payload =
          jsonDecode((await outboxOf(ownerA)).single.payloadJson!) as Map;
      expect(payload['image_url'], 'https://cdn.test/promoted.jpg');
      expect(payload['images'], isEmpty);
    });

    test('existing с исчезнувшим id пропускается (строки нет)', () async {
      final wish = await repo.createWish(title: 'Фото');
      await markSynced();

      await repo.updateWish(
        wish,
        images: const [WishImageInput.existing('img-ghost')],
      );

      expect(await imagesOf(wish.id), isEmpty);
    });

    test('outbox: частичный media-update мержится с pending-полями '
        '(title не затирается)', () async {
      final wish = await repo.createWish(title: 'Фото');
      await markSynced();

      await repo.updateWish(wish.copyWith(title: 'Новое название'));
      // Симуляция post-upload op — частичный payload.
      await OutboxStore(db).enqueue(
        ownerId: ownerA,
        entityType: WishEntityTypes.wish,
        entityId: wish.id,
        operation: OutboxOp.update,
        payload: {'image_url': 'https://cdn.test/img.png'},
      );

      final ops = await outboxOf(ownerA);
      expect(ops, hasLength(1));
      final payload = jsonDecode(ops.single.payloadJson!) as Map;
      expect(payload['title'], 'Новое название');
      expect(payload['image_url'], 'https://cdn.test/img.png');
    });
  });
}
