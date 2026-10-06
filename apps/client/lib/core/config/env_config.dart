import 'package:flutter/foundation.dart';

/// Конфигурация окружения приложения.
///
/// Значения передаются через `--dart-define` во время сборки.
/// По умолчанию: debug/profile — локальный стек
/// (`https://api.chtohochu.test`), release — production
/// (`https://api.chtohochu.ru`). Для production-сборок
/// `--dart-define=API_BASE_URL=...` обязателен лишь для нестандартных
/// хостов.
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
        : (kReleaseMode
              ? 'https://api.chtohochu.ru'
              : 'https://api.chtohochu.test');

    // Reverb app key — публичный идентификатор (по дизайну уезжает
    // в клиенты, как Pusher app key). Не секрет. Без явного
    // `--dart-define=REVERB_APP_KEY` ключ выбирается по хосту API:
    // локальный стек → ключ из docker-compose, прод → прод-ключ.
    const definedReverbKey = String.fromEnvironment('REVERB_APP_KEY');
    final reverbAppKey = definedReverbKey.isNotEmpty
        ? definedReverbKey
        : (_isLocalHost(apiBaseUrl)
              ? 'local-app-key'
              : '34c7a5e068b7da49a052bdf1e260cebe');

    // Release-сборка не должна указывать на локальный/небезопасный
    // адрес — это misconfiguration сборки, а не runtime-ошибка
    // пользователя. Fail-fast: лучше падение на старте, чем
    // незаметно «мёртвый» релиз.
    if (kReleaseMode) {
      final isLocal = _isLocalHost(apiBaseUrl);
      if (isLocal || Uri.tryParse(apiBaseUrl)?.scheme != 'https') {
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

  /// Локальный/dev хост API: `*.chtohochu.test`, localhost, приватные IP.
  static bool _isLocalHost(String url) {
    final host = Uri.tryParse(url)?.host ?? '';
    return host.isEmpty ||
        host == 'localhost' ||
        host == '127.0.0.1' ||
        host.endsWith('.test') ||
        host.startsWith('192.168.') ||
        host.startsWith('10.') ||
        host.startsWith('172.');
  }
}
