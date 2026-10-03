import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/preferences_service.dart';
import '../domain/friend.dart';

/// Сетевые чтения Friends-домена: поиск пользователей и refresh
/// публичного профиля/желаний друга.
///
/// Это НЕ repository: репозиторий сети не трогает и читает только
/// Drift. Сервис лежит на стороне sync: результат GET-запроса
/// записывается в Drift (cached_users / friend_wishes), UI
/// продолжает читать локальные стримы.
class FriendsRemoteService {
  FriendsRemoteService(this._dio, this._db, this._prefs);

  final Dio _dio;
  final AppDatabase _db;
  final PreferencesService _prefs;

  /// Простой TTL кэша желаний друга (MVP): stale > 5 минут → refresh.
  static const wishesTtl = Duration(minutes: 5);

  String? get _ownerId => _prefs.currentUserId();

  static Friend _publicUser(Map<String, dynamic> m) => Friend(
    id: m['id'] as String,
    name: m['name'] as String? ?? '',
    username: m['username'] as String? ?? '',
    avatarUrl: m['avatar_url'] as String?,
  );

  /// `GET /users/search?q=` — network-only поиск. Результаты
  /// (PublicUserResource) кэшируются в `cached_users`; дружеские
  /// строки не создаются — появление в поиске ≠ дружба.
  Future<List<Friend>> searchUsers(String query) async {
    final ownerId = _ownerId;
    if (ownerId == null) return const [];
    final res = await _dio.get<Map<String, dynamic>>(
      '/users/search',
      queryParameters: {'q': query},
    );
    final raw = res.data?['data'];
    if (raw is! List) return const [];

    final now = DateTime.now();
    final users = <Friend>[
      for (final item in raw) _publicUser(item as Map<String, dynamic>),
    ];
    // Аккаунт мог смениться, пока запрос был в полёте. Проверка
    // ВНУТРИ транзакции с записью: между внешней проверкой и циклом
    // insert'ов мог бы вклиниться clearAccountData → воскрешение
    // вычищенных строк кэша.
    await _db.transaction(() async {
      if (_prefs.currentUserId() != ownerId) return;
      for (final friend in users) {
        await _db
            .into(_db.cachedUsers)
            .insertOnConflictUpdate(
              CachedUsersCompanion(
                ownerId: Value(ownerId),
                userId: Value(friend.id),
                name: Value(friend.name),
                username: Value(friend.username),
                avatarUrl: Value(friend.avatarUrl),
                cachedAt: Value(now),
              ),
            );
      }
    });
    return users;
  }

  /// Refresh профиля друга: `GET /friends/{user}` → cached_users.
  /// 404 = дружба недоступна — кэш не фабрикуем, friendship-строку
  /// не трогаем (состояние разрулит snapshot pull).
  Future<void> refreshFriendProfile(String friendId) async {
    final ownerId = _ownerId;
    if (ownerId == null) return;
    try {
      final res = await _dio.get<Map<String, dynamic>>('/friends/$friendId');
      final data = res.data?['data'];
      if (data is! Map<String, dynamic>) return;
      final friend = _publicUser(data);
      await _db.transaction(() async {
        if (_prefs.currentUserId() != ownerId) return;
        await _db
            .into(_db.cachedUsers)
            .insertOnConflictUpdate(
              CachedUsersCompanion(
                ownerId: Value(ownerId),
                userId: Value(friend.id),
                name: Value(friend.name),
                username: Value(friend.username),
                avatarUrl: Value(friend.avatarUrl),
                cachedAt: Value(DateTime.now()),
              ),
            );
      });
    } on DioException catch (e) {
      // Сеть/404/401 — кэш остаётся источником UI; 401 обработает
      // очередной прогон SyncEngine (единый auth-expired flow).
      if (e.response?.statusCode == 401) rethrow;
    }
  }

  /// Refresh желаний друга: `GET /friends/{user}/wishes` →
  /// snapshot-замена `friend_wishes` (remote wins — локальных
  /// правок чужих желаний не существует).
  ///
  /// 404 = друг недоступен → кэш инвалидируется (пустой snapshot).
  Future<void> refreshFriendWishes(String friendId) async {
    final ownerId = _ownerId;
    if (ownerId == null) return;
    final now = DateTime.now();
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/friends/$friendId/wishes',
      );
      final raw = res.data?['data'];
      if (raw is! List) return;
      final snapshot = <FriendWishesCompanion>[
        for (final item in raw)
          _wishRow(ownerId, friendId, item as Map<String, dynamic>, now),
      ];
      await _db.transaction(() async {
        // In-tx recheck: аккаунт мог смениться, пока GET был
        // в полёте — кэш чужого аккаунта не воскресает.
        if (_prefs.currentUserId() != ownerId) return;
        await _db.replaceFriendWishes(ownerId, friendId, snapshot);
      });
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401) rethrow;
      if (code == 404) {
        // Друг/желания недоступны — сбрасываем кэш, не фабрикуя
        // данные: UI покажет «пока нет желаний».
        await _db.transaction(() async {
          if (_prefs.currentUserId() != ownerId) return;
          await _db.replaceFriendWishes(ownerId, friendId, const []);
        });
      }
      // 5xx/network — кэш остаётся, повтор при следующем входе.
    }
  }

  /// Refresh желаний друга по TTL: свежий кэш пропускает сеть,
  /// оффлайн — кэш остаётся источником (stale лучше пустого экрана).
  Future<void> refreshFriendDataIfStale(String friendId) async {
    final ownerId = _ownerId;
    if (ownerId == null) return;
    await refreshFriendProfile(friendId);
    final fetchedAt = await _db.friendWishesFetchedAt(ownerId, friendId);
    if (fetchedAt != null && DateTime.now().difference(fetchedAt) < wishesTtl) {
      return;
    }
    await refreshFriendWishes(friendId);
  }

  FriendWishesCompanion _wishRow(
    String ownerId,
    String friendId,
    Map<String, dynamic> m,
    DateTime now,
  ) {
    return FriendWishesCompanion(
      id: Value(m['id'] as String),
      ownerId: Value(ownerId),
      friendId: Value(friendId),
      title: Value(m['title'] as String),
      description: Value(m['description'] as String?),
      price: Value(m['price'] as int?),
      link: Value(m['link'] as String?),
      imageUrl: Value(m['image_url'] as String?),
      createdAt: Value(DateTime.parse(m['created_at'] as String)),
      updatedAt: Value(DateTime.parse(m['updated_at'] as String)),
      fetchedAt: Value(now),
    );
  }
}

/// Провайдер сетевых чтений Friends.
final friendsRemoteServiceProvider = Provider<FriendsRemoteService>((ref) {
  return FriendsRemoteService(
    ref.read(apiClientProvider),
    ref.read(appDatabaseProvider),
    ref.read(preferencesServiceProvider),
  );
});
