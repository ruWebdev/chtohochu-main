import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/sync/outbox_store.dart';
import '../../auth/domain/user.dart';

/// Абстракция репозитория профиля текущего пользователя.
///
/// Feature-код зависит только от этого интерфейса.
/// Реализация — [DriftProfileRepository]: таблица `profiles`
/// является единственным источником данных для UI; HTTP живёт
/// в SyncEngine (`PATCH /me`).
abstract interface class ProfileRepository {
  /// Реактивный профиль текущего аккаунта (source of truth).
  ///
  /// `null`, если нет сессии или профиль ещё не записан.
  Stream<User?> watchProfile();

  /// Профиль текущего аккаунта, или `null`.
  Future<User?> getProfile();

  /// Обновить профиль локально + поставить `update`-операцию
  /// в outbox — одной транзакцией.
  ///
  /// Семантика полей — whole-object PATCH: [name], [username] и
  /// [avatarUrl] отправляются целиком; `null` очищает поле.
  /// Email через этот путь не меняется.
  Future<User> updateProfile({
    required String name,
    String? username,
    String? avatarUrl,
  });
}

/// Ошибка репозитория профиля.
sealed class ProfileError implements Exception {
  const ProfileError(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Ошибка хранилища/состояния при работе с профилем.
class ProfileStorageError extends ProfileError {
  const ProfileStorageError() : super('storage');
}

/// Действие требует авторизованного пользователя.
class ProfileNotAuthenticatedError extends ProfileError {
  const ProfileNotAuthenticatedError() : super('not_authenticated');
}

/// Профиль не найден в локальном хранилище.
class ProfileNotFoundError extends ProfileError {
  const ProfileNotFoundError() : super('not_found');
}

/// Провайдер `ProfileRepository` — Drift-backed реализация.
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return DriftProfileRepository(
    ref.read(appDatabaseProvider),
    ref.read(preferencesServiceProvider),
  );
});

/// Репозиторий профиля поверх Drift.
///
/// Identity профиля — естественная: `entityId = ownerId`
/// (у профиля нет отдельного server UUID, PATCH идёт на `/me`).
/// Мутация — одна транзакция: запись `profiles` + outbox.
/// Сети здесь нет — доставкой занимается SyncEngine.
class DriftProfileRepository implements ProfileRepository {
  DriftProfileRepository(this._db, this._prefs);

  final AppDatabase _db;
  final PreferencesService _prefs;

  String get _ownerId {
    final id = _prefs.currentUserId();
    if (id == null) {
      throw const ProfileNotAuthenticatedError();
    }
    return id;
  }

  static User _toDomain(Profile r) => User(
    id: r.id,
    email: r.email,
    name: r.name,
    username: r.username,
    avatarUrl: r.avatarUrl,
  );

  @override
  Stream<User?> watchProfile() {
    final ownerId = _prefs.currentUserId();
    // Без сессии профиля нет — пустой стрим, а не исключение:
    // providers могут пересчитываться на logout-переходах.
    if (ownerId == null) return Stream.value(null);
    return _db
        .watchProfile(ownerId)
        .map((row) => row == null ? null : _toDomain(row));
  }

  @override
  Future<User?> getProfile() async {
    final ownerId = _prefs.currentUserId();
    if (ownerId == null) return null;
    final row = await _db.profileById(ownerId);
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<User> updateProfile({
    required String name,
    String? username,
    String? avatarUrl,
  }) async {
    final ownerId = _ownerId;
    final existing = await _db.profileById(ownerId);
    if (existing == null) {
      throw const ProfileNotFoundError();
    }

    await _db.transaction(() async {
      await (_db.update(
        _db.profiles,
      )..where((p) => p.id.equals(ownerId))).write(
        ProfilesCompanion(
          name: Value(name),
          username: Value(username),
          avatarUrl: Value(avatarUrl),
          updatedAt: Value(DateTime.now()),
        ),
      );
      // Whole-object update: payload несёт финальное желаемое
      // состояние — compaction update+update = последняя запись.
      await OutboxStore(_db).enqueue(
        ownerId: ownerId,
        entityType: 'profile',
        entityId: ownerId,
        operation: OutboxOp.update,
        payload: {'name': name, 'username': username, 'avatar_url': avatarUrl},
      );
    });

    return User(
      id: ownerId,
      email: existing.email,
      name: name,
      username: username,
      avatarUrl: avatarUrl,
    );
  }
}
