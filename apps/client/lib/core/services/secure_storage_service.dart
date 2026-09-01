import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/storage_keys.dart';

/// Обёртка над `flutter_secure_storage` для хранения учётных данных.
///
/// Используется ТОЛЬКО для учётных данных — никогда для бизнес-данных.
class SecureStorageService {
  SecureStorageService(this._storage);

  final FlutterSecureStorage _storage;

  /// Сохраняет access-токен.
  Future<void> saveAccessToken(String token) =>
      _storage.write(key: StorageKeys.accessToken, value: token);

  /// Читает access-токен. Возвращает `null`, если токена нет.
  Future<String?> readAccessToken() =>
      _storage.read(key: StorageKeys.accessToken);

  /// Сохраняет refresh-токен.
  Future<void> saveRefreshToken(String token) =>
      _storage.write(key: StorageKeys.refreshToken, value: token);

  /// Читает refresh-токен. Возвращает `null`, если токена нет.
  Future<String?> readRefreshToken() =>
      _storage.read(key: StorageKeys.refreshToken);

  /// Удаляет все сохранённые токены.
  Future<void> clearTokens() async {
    await _storage.delete(key: StorageKeys.accessToken);
    await _storage.delete(key: StorageKeys.refreshToken);
  }
}

/// Провайдер экземпляра `FlutterSecureStorage`.
final flutterSecureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(aOptions: AndroidOptions()),
);

/// Провайдер `SecureStorageService`.
final secureStorageServiceProvider = Provider<SecureStorageService>(
  (ref) => SecureStorageService(ref.read(flutterSecureStorageProvider)),
);
