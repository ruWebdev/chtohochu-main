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
  const EnvConfig._({
    required this.apiBaseUrl,
    required this.environment,
    required this.reverbAppKey,
  });

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

    // Reverb app key — публичный идентификатор (по дизайну уезжает
    // в клиенты, как Pusher app key). Не секрет. Для локального стека:
    // `--dart-define=REVERB_APP_KEY=local-app-key`.
    const reverbAppKey = String.fromEnvironment(
      'REVERB_APP_KEY',
      defaultValue: '34c7a5e068b7da49a052bdf1e260cebe',
    );

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

    return EnvConfig._(
      apiBaseUrl: apiBaseUrl,
      environment: environment,
      reverbAppKey: reverbAppKey,
    );
  }

  /// Базовый URL API.
  final String apiBaseUrl;

  /// Публичный ключ Reverb-приложения (wss://{apiHost}/app/{key}).
  final String reverbAppKey;

  /// Имя окружения: `dev`, `staging`, `prod`.
  final String environment;

  /// `true`, если приложение собрано для production.
  bool get isProduction => environment == 'prod';
}
