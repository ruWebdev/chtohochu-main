import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/storage_keys.dart';

/// Обёртка над `SharedPreferences` для простых флагов и настроек.
///
/// Используется для onboarding-флагов, режима темы и других простых
/// preference-значений. Бизнес-данные хранятся через репозитории.
class PreferencesService {
  PreferencesService(this._prefs);

  final SharedPreferences _prefs;

  // --- Onboarding ---

  /// Пройден ли onboarding.
  bool isOnboardingComplete() =>
      _prefs.getBool(StorageKeys.onboardingComplete) ?? false;

  /// Отметить onboarding как пройденный.
  Future<void> setOnboardingComplete() =>
      _prefs.setBool(StorageKeys.onboardingComplete, true);

  // --- First wish flow ---

  /// Показан ли flow создания первого желания.
  bool isFirstWishFlowShown() =>
      _prefs.getBool(StorageKeys.firstWishFlowShown) ?? false;

  /// Отметить, что flow первого желания показан.
  Future<void> setFirstWishFlowShown() =>
      _prefs.setBool(StorageKeys.firstWishFlowShown, true);

  /// Сбросить флаг first-wish flow (logout — следующий пользователь
  /// без желаний должен увидеть flow заново).
  Future<void> resetFirstWishFlowShown() =>
      _prefs.remove(StorageKeys.firstWishFlowShown);

  // --- Current user identity ---

  /// Id текущего пользователя (persisted identity для offline
  /// cold start; все account-scoped записи в Drift имеют owner_id).
  String? currentUserId() => _prefs.getString(StorageKeys.currentUserId);

  /// Сохранить id текущего пользователя при логине.
  Future<void> setCurrentUserId(String id) =>
      _prefs.setString(StorageKeys.currentUserId, id);

  /// Убрать указатель на текущего пользователя (logout/401).
  Future<void> clearCurrentUserId() => _prefs.remove(StorageKeys.currentUserId);

  // --- Legacy wishes cache → Drift migration ---

  /// Прочитать legacy JSON-кэш желаний (только для one-time
  /// миграции в Drift — новые записи в него не пишутся).
  String? readLegacyWishesCache() => _prefs.getString(StorageKeys.wishesCache);

  /// Очистить legacy кэш желаний после импорта.
  Future<void> clearLegacyWishesCache() =>
      _prefs.remove(StorageKeys.wishesCache);

  /// Выполнена ли one-time миграция legacy-кэша в Drift.
  bool isWishesMigrated() =>
      _prefs.getBool(StorageKeys.wishesMigrated) ?? false;

  /// Отметить миграцию выполненной.
  Future<void> setWishesMigrated() =>
      _prefs.setBool(StorageKeys.wishesMigrated, true);

  // --- Media dirs: wish_photos/ → media/wishes/ ---

  /// Выполнен ли перенос локальных фото в media-структуру.
  bool isMediaDirsMigrated() =>
      _prefs.getBool(StorageKeys.mediaDirsMigrated) ?? false;

  /// Отметить перенос выполненным.
  Future<void> setMediaDirsMigrated() =>
      _prefs.setBool(StorageKeys.mediaDirsMigrated, true);

  // --- Legacy shopping lists cache → Drift migration ---

  /// Прочитать legacy JSON-кэш списков покупок (только для
  /// one-time миграции в Drift — новые записи в него не пишутся).
  String? readShoppingListsCache() =>
      _prefs.getString(StorageKeys.shoppingListsCache);

  /// Очистить legacy кэш списков после импорта.
  Future<void> clearShoppingListsCache() =>
      _prefs.remove(StorageKeys.shoppingListsCache);

  /// Выполнена ли one-time миграция shopping-кэша в Drift.
  bool isShoppingListsMigrated() =>
      _prefs.getBool(StorageKeys.shoppingListsMigrated) ?? false;

  /// Отметить миграцию выполненной.
  Future<void> setShoppingListsMigrated() =>
      _prefs.setBool(StorageKeys.shoppingListsMigrated, true);

  // --- Friends cache (legacy mock-хранилище) ---

  /// Очистить legacy кэш id друзей (mock-каталог u1–u5; реальных
  /// данных там не было — Drift заполняется pull'ом `/friends`).
  Future<void> clearFriendsCache() => _prefs.remove(StorageKeys.friendsCache);

  // --- User profile cache (временное mock-хранилище) ---

  /// Прочитать JSON-кэш профиля текущего пользователя.
  String? readUserProfileCache() =>
      _prefs.getString(StorageKeys.userProfileCache);

  /// Записать JSON-кэш профиля текущего пользователя.
  Future<void> writeUserProfileCache(String json) =>
      _prefs.setString(StorageKeys.userProfileCache, json);

  /// Очистить кэш профиля текущего пользователя.
  Future<void> clearUserProfileCache() =>
      _prefs.remove(StorageKeys.userProfileCache);

  // --- Theme mode ---

  /// Сохранить режим темы.
  Future<void> setThemeMode(String mode) =>
      _prefs.setString(StorageKeys.themeMode, mode);

  /// Прочитать режим темы.
  String? readThemeMode() => _prefs.getString(StorageKeys.themeMode);
}

/// Провайдер `SharedPreferences`.
///
/// Инициализируется в `main.dart` и передаётся через override.
/// В тестах используется `SharedPreferences.setMockInitialValues`.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider должен быть overridden в main.dart или тестах',
  );
});

/// Провайдер `PreferencesService`.
final preferencesServiceProvider = Provider<PreferencesService>((ref) {
  return PreferencesService(ref.read(sharedPreferencesProvider));
});
