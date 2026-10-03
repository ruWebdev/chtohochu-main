import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/sync/outbox_store.dart';
import '../../wishes/domain/wish.dart';
import '../domain/friend.dart';

/// Абстракция репозитория друзей.
///
/// Feature-код зависит только от этого интерфейса. Реализация —
/// [DriftFriendsRepository]: Drift — единственный источник данных
/// для UI; HTTP живёт в SyncEngine/FriendsRemoteService.
abstract interface class FriendsRepository {
  /// Реактивный поток друзей с их кэшированными желаниями
  /// (source of truth для UI).
  Stream<List<Friend>> watchFriends();

  /// Друзья текущего пользователя.
  Future<List<Friend>> getFriends();

  /// Друг по id, или `null` если не найден/удалён.
  Future<Friend?> getFriendById(String id);

  /// Добавить пользователя в друзья (локально, outbox → sync).
  ///
  /// [user] — публичная проекция из поиска: сразу кэшируется в
  /// `cached_users`, чтобы друг был читаем оффлайн до sync.
  Future<Friend> addFriend(Friend user);

  /// Удалить друга (tombstone + outbox delete).
  Future<void> removeFriend(String id);
}

/// Ошибка репозитория друзей.
///
/// [message] — технический код для логов/отладки, НЕ пользовательский
/// текст. Текст выбирает presentation через `friendsErrorMessage`.
sealed class FriendsError implements Exception {
  const FriendsError(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Пользователь не найден / операция невозможна.
class FriendNotFoundError extends FriendsError {
  const FriendNotFoundError() : super('not_found');
}

/// Ошибка хранилища/состояния при работе с друзьями.
class FriendsStorageError extends FriendsError {
  const FriendsStorageError() : super('storage');
}

/// Действие требует авторизованного пользователя.
class FriendsNotAuthenticatedError extends FriendsError {
  const FriendsNotAuthenticatedError() : super('not_authenticated');
}

/// Попытка добавить в друзья самого себя.
class FriendsCannotAddSelfError extends FriendsError {
  const FriendsCannotAddSelfError() : super('cannot_add_self');
}

/// Провайдер `FriendsRepository` — Drift-backed реализация.
final friendsRepositoryProvider = Provider<FriendsRepository>((ref) {
  return DriftFriendsRepository(
    ref.read(appDatabaseProvider),
    ref.read(preferencesServiceProvider),
  );
});

/// Тип сущности дружбы в общем outbox.
///
/// Identity связи на проводе — `friend_id` (UUID другого
/// пользователя): backend оперирует `POST /friends {user_id}` и
/// `DELETE /friends/{user}`, серверный UUID Friendship клиенту
/// не отдаётся. Поэтому outbox `entityId = friendId` — пара
/// (owner_id, friend_id) уникальна и даёт естественную
/// идемпотентность (серверный 409 на дубликат пары).
abstract final class FriendsEntityTypes {
  static const String friendship = 'friendship';
}

/// Репозиторий друзей поверх Drift.
///
/// Мутации атомарны: одна транзакция = запись сущности +
/// outbox-операция. Желания друзей хранятся в отдельной таблице
/// `friend_wishes` — owner_id там это владелец КЭША (текущий
/// аккаунт), а не автор желания.
class DriftFriendsRepository implements FriendsRepository {
  DriftFriendsRepository(this._db, this._prefs);

  final AppDatabase _db;
  final PreferencesService _prefs;

  String get _ownerId {
    final id = _prefs.currentUserId();
    if (id == null) {
      throw const FriendsNotAuthenticatedError();
    }
    return id;
  }

  static Wish _wishToDomain(FriendWishRow r) => Wish(
    id: r.id,
    title: r.title,
    description: r.description,
    price: r.price,
    link: r.link,
    imageUrl: r.imageUrl,
    createdAt: r.createdAt,
  );

  @override
  Stream<List<Friend>> watchFriends() {
    return _db.watchFriendsData(_ownerId).map((rows) {
      // Группировка join-строк `friendship + cachedUser? + wish?`.
      final byId = <String, Friend>{};
      final wishesByFriend = <String, List<Wish>>{};
      final order = <String>[];
      for (final row in rows) {
        final f = row.readTable(_db.friendships);
        final u = row.readTableOrNull(_db.cachedUsers);
        final w = row.readTableOrNull(_db.friendWishes);
        if (!byId.containsKey(f.friendId)) {
          byId[f.friendId] = Friend(
            id: f.friendId,
            name: u?.name ?? '',
            username: u?.username ?? '',
            avatarUrl: u?.avatarUrl,
          );
          order.add(f.friendId);
        }
        if (w != null) {
          wishesByFriend
              .putIfAbsent(f.friendId, () => [])
              .add(_wishToDomain(w));
        }
      }
      return [
        for (final id in order)
          byId[id]!.copyWith(wishes: wishesByFriend[id] ?? const []),
      ];
    });
  }

  @override
  Future<List<Friend>> getFriends() => watchFriends().first;

  @override
  Future<Friend?> getFriendById(String id) async {
    final ownerId = _ownerId;
    final row = await _db.friendshipByIdAny(ownerId, id);
    if (row == null || row.deletedAt != null) return null;
    final user = await _db.cachedUserById(ownerId, id);
    final wishes = await _db.friendWishesOf(ownerId, id);
    return Friend(
      id: id,
      name: user?.name ?? '',
      username: user?.username ?? '',
      avatarUrl: user?.avatarUrl,
      wishes: [for (final w in wishes) _wishToDomain(w)],
    );
  }

  @override
  Future<Friend> addFriend(Friend user) async {
    final ownerId = _ownerId;
    if (user.id == ownerId) {
      throw const FriendsCannotAddSelfError();
    }
    final now = DateTime.now();
    final existing = await _db.friendshipByIdAny(ownerId, user.id);
    if (existing != null && existing.deletedAt == null) {
      // Уже в друзьях локально. Незавершённые операции:
      //   pending create   — sync идёт, no-op;
      //   failed create    — re-add = повторить намерение: revive;
      //   pending/failed delete — re-add отменяет удаление:
      //                         compaction заменит его create'ом.
      final ops = await _db.opsFor(ownerId, user.id);
      final pendingCreate = ops.any(
        (o) => o.operation == OutboxOp.create && o.status == 'pending',
      );
      if (ops.isEmpty || pendingCreate) {
        return (await getFriendById(user.id))!;
      }
      await _db.transaction(() async {
        await OutboxStore(_db).enqueue(
          ownerId: ownerId,
          entityType: FriendsEntityTypes.friendship,
          entityId: user.id,
          operation: OutboxOp.create,
          payload: {'user_id': user.id},
        );
      });
      return (await getFriendById(user.id))!;
    }

    await _db.transaction(() async {
      // Проекция пользователя — сразу в кэш, чтобы друг был
      // читаем оффлайн ещё до ответа сервера.
      await _db
          .into(_db.cachedUsers)
          .insertOnConflictUpdate(
            CachedUsersCompanion(
              ownerId: Value(ownerId),
              userId: Value(user.id),
              name: Value(user.name),
              username: Value(user.username),
              avatarUrl: Value(user.avatarUrl),
              cachedAt: Value(now),
            ),
          );
      if (existing == null) {
        await _db
            .into(_db.friendships)
            .insert(
              FriendshipsCompanion(
                ownerId: Value(ownerId),
                friendId: Value(user.id),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
      } else {
        // Tombstone от незавершённого delete — снимаем.
        await (_db.update(_db.friendships)..where(
              (f) => f.friendId.equals(user.id) & f.ownerId.equals(ownerId),
            ))
            .write(
              FriendshipsCompanion(
                deletedAt: const Value(null),
                updatedAt: Value(now),
              ),
            );
      }
      await OutboxStore(_db).enqueue(
        ownerId: ownerId,
        entityType: FriendsEntityTypes.friendship,
        entityId: user.id, // identity связи на проводе = friend_id
        operation: OutboxOp.create,
        payload: {'user_id': user.id},
      );
    });

    return user;
  }

  @override
  Future<void> removeFriend(String id) async {
    final ownerId = _ownerId;
    await _db.transaction(() async {
      final outbox = OutboxStore(_db);
      final existing = await _db.friendshipByIdAny(ownerId, id);
      if (existing == null || existing.deletedAt != null) return;

      if (await outbox.hasUnsyncedCreate(ownerId, id)) {
        // Дружба никогда не доезжала до сервера — физическое
        // удаление, HTTP не нужен.
        await (_db.delete(_db.friendships)
              ..where((f) => f.friendId.equals(id) & f.ownerId.equals(ownerId)))
            .go();
        await (_db.delete(_db.friendWishes)
              ..where((w) => w.friendId.equals(id) & w.ownerId.equals(ownerId)))
            .go();
      } else {
        await (_db.update(_db.friendships)
              ..where((f) => f.friendId.equals(id) & f.ownerId.equals(ownerId)))
            .write(FriendshipsCompanion(deletedAt: Value(DateTime.now())));
      }
      await outbox.enqueue(
        ownerId: ownerId,
        entityType: FriendsEntityTypes.friendship,
        entityId: id,
        operation: OutboxOp.delete,
      );
    });
  }
}
