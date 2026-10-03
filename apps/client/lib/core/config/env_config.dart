import 'package:flutter/foundation.dart';

/// Конфигурация окружения приложения.
///
/// Значения передаются через `--dart-define` во время сборки.
/// По умолчанию приложение обращается к production API
/// (`https://api.chtohochu.ru`) во всех режимах, включая debug.
/// Для локального стека передайте
/// `--dart-define=API_BASE_URL=https://api.chtohochu.test`.
/// Backend живёт за domain-routing (`Route::domain(APP_DOMAIN_API)`) —
/// `http://localhost:8000` не является рабочим адресом API.
///
/// `API_BASE_URL` — хост БЕЗ префикса `/api/v1` (клиент добавляет
/// `ApiConstants.apiPrefix` сам).
class EnvConfig {
  const EnvConfig._({required this.apiBaseUrl, required this.environment});

  /// Создаёт конфигурацию из `--dart-define` переменных.
  factory EnvConfig.fromEnvironment() {
    const definedUrl = String.fromEnvironment('API_BASE_URL');
    const environment = String.fromEnvironment(
      'ENVIRONMENT',
      defaultValue: 'dev',
    );
    final apiBaseUrl = definedUrl.isNotEmpty
        ? definedUrl
        : 'https://api.chtohochu.ru';

    // Release-сборка не должна указывать на локальный/небезопасный
    // адрес — это misconfiguration сборки, а не runtime-ошибка
    // пользователя. Fail-fast: лучше падение на старте, чем
    // незаметно «мёртвый» релиз.
    if (kReleaseMode) {
      final uri = Uri.tryParse(apiBaseUrl);
      final host = uri?.host ?? '';
      final isLocal =
          host.isEmpty ||
          host == 'localhost' ||
          host == '127.0.0.1' ||
          host.endsWith('.test') ||
          host.startsWith('192.168.') ||
          host.startsWith('10.') ||
          host.startsWith('172.');
      if (isLocal || uri?.scheme != 'https') {
        throw StateError(
          'Release build requires a production HTTPS API_BASE_URL, '
          'got: $apiBaseUrl',
        );
      }
    }

    return EnvConfig._(apiBaseUrl: apiBaseUrl, environment: environment);
  }

  /// Базовый URL API.
  final String apiBaseUrl;

  /// Имя окружения: `dev`, `staging`, `prod`.
  final String environment;

  /// `true`, если приложение собрано для production.
  bool get isProduction => environment == 'prod';
}
