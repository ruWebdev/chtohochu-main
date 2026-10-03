import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/sync/sync_engine.dart';
import '../../data/friends_remote_service.dart';
import '../../data/friends_repository.dart';
import '../../domain/friend.dart';
import '../../../wishes/domain/wish.dart';

/// Контроллер списка друзей.
///
/// Source of truth — Drift-стрим репозитория: UI реактивно
/// следует за локальной БД, сеть не блокирует отображение.
class FriendsController extends StreamNotifier<List<Friend>> {
  @override
  Stream<List<Friend>> build() {
    return ref.watch(friendsRepositoryProvider).watchFriends();
  }

  /// Триггер онлайн-refresh (snapshot pull живёт в SyncEngine и
  /// вызывается по attach/foreground-триггерам).
  Future<void> refresh() => ref.read(syncEngineProvider).requestSync();

  /// Добавить пользователя в друзья.
  ///
  /// Локально мгновенно: friendship + cached_user + outbox.
  /// Возвращает `true` при успехе; если уже в друзьях — no-op `true`.
  Future<bool> addFriend(Friend user) async {
    final current = state.value ?? const <Friend>[];
    if (current.any((f) => f.id == user.id)) return true;
    try {
      await ref.read(friendsRepositoryProvider).addFriend(user);
      return true;
    } on FriendsError {
      return false;
    }
  }

  /// Удалить друга (tombstone + outbox — UI обновится из стрима).
  Future<void> removeFriend(String id) async {
    await ref.read(friendsRepositoryProvider).removeFriend(id);
  }
}

/// Провайдер списка друзей.
final friendsControllerProvider =
    StreamNotifierProvider<FriendsController, List<Friend>>(
      FriendsController.new,
    );

/// Друг по id из стрима.
///
/// `null`, пока список грузится или друг не найден/удалён.
final friendByIdProvider = Provider.family<Friend?, String>((ref, id) {
  final friends = ref.watch(friendsControllerProvider).value;
  if (friends == null) return null;
  for (final f in friends) {
    if (f.id == id) return f;
  }
  return null;
});

/// Желание друга по id (из локального кэша `friend_wishes`).
final friendWishByIdProvider =
    Provider.family<Wish?, (String friendId, String wishId)>((ref, key) {
      final friend = ref.watch(friendByIdProvider(key.$1));
      if (friend == null) return null;
      for (final w in friend.wishes) {
        if (w.id == key.$2) return w;
      }
      return null;
    });

/// Поиск пользователей по запросу — network-only
/// (`GET /users/search`). Результаты кэшируются в `cached_users`
/// самим сервисом; дружба не создаётся.
///
/// `autoDispose` обязателен: каждое значение family-аргумента
/// (каждый введённый запрос) — отдельная запись провайдера; без него
/// результаты всех промежуточных запросов жили бы всю сессию.
final friendSearchProvider = FutureProvider.autoDispose
    .family<List<Friend>, String>((ref, query) {
      if (query.trim().isEmpty) return Future.value(const <Friend>[]);
      return ref.read(friendsRemoteServiceProvider).searchUsers(query);
    });

/// Refresh данных друга при открытии профиля: профиль +
/// желания по TTL. Оффлайн — запрос падает, кэш остаётся
/// источником UI (autoDispose = повтор при каждом входе).
final friendDataRefreshProvider = FutureProvider.autoDispose
    .family<void, String>((ref, friendId) async {
      await ref
          .read(friendsRemoteServiceProvider)
          .refreshFriendDataIfStale(friendId);
    });
