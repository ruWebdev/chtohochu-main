/// Ключи для безопасного хранилища (flutter_secure_storage).
///
/// Используются только для учётных данных — никогда для бизнес-данных.
class StorageKeys {
  const StorageKeys._();

  /// Ключ хранения access-токена Sanctum.
  static const String accessToken = 'access_token';

  /// Ключ хранения refresh-токена.
  static const String refreshToken = 'refresh_token';
}
