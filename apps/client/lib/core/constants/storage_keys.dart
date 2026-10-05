/// Ключи для хранилищ приложения.
///
/// `flutter_secure_storage` — только учётные данные.
/// `SharedPreferences` — простые флаги и настройки.
class StorageKeys {
  const StorageKeys._();

  // --- Secure storage (учётные данные) ---

  /// Ключ хранения access-токена Sanctum.
  static const String accessToken = 'access_token';

  /// Ключ хранения refresh-токена.
  static const String refreshToken = 'refresh_token';

  // --- SharedPreferences (флаги/настройки) ---

  /// Флаг прохождения onboarding.
  static const String onboardingComplete = 'onboarding_complete';

  /// Флаг: показан flow создания первого желания.
  static const String firstWishFlowShown = 'first_wish_flow_shown';

  /// Режим темы: 'light', 'dark', 'system'.
  static const String themeMode = 'theme_mode';

  /// Id текущего пользователя — persisted identity для offline
  /// cold start и owner-scoping локальной БД.
  static const String currentUserId = 'current_user_id';

  /// One-time флаг: legacy `wishes_cache` уже импортирован в Drift.
  static const String wishesMigrated = 'wishes_migrated';

  /// One-time перенос `Documents/wish_photos/` в `Documents/media/`.
  static const String mediaDirsMigrated = 'media_dirs_migrated';

  /// Локальное хранилище желаний (JSON) — временное mock-решение.
  static const String wishesCache = 'wishes_cache';

  /// Локальное хранилище списков покупок (JSON) — legacy-кэш,
  /// читается только one-time миграцией в Drift.
  static const String shoppingListsCache = 'shopping_lists_cache';

  /// One-time флаг: legacy `shopping_lists_cache` уже импортирован
  /// в Drift.
  static const String shoppingListsMigrated = 'shopping_lists_migrated';

  /// Локальное хранилище id друзей (JSON) — временное mock-решение.
  static const String friendsCache = 'friends_cache';

  /// Локальное хранилище профиля текущего пользователя (JSON) —
  /// временное mock-решение (name/username/avatarUrl).
  static const String userProfileCache = 'user_profile_cache';
}
