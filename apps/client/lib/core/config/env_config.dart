import 'package:flutter/foundation.dart';

/// Конфигурация окружения приложения.
///
/// Значения передаются через `--dart-define` во время сборки.
/// По умолчанию приложение обращается к production API
/// (`https://api.chtohochu.ru`) во всех режимах, включая debug.
/// Для локального стека передайте
/// `--dart-define=API_BASE_URL=https://api.chtohochu.test` —
/// ключ Reverb подставится автоматически.
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
    required this.vkAppId,
    required this.yandexClientId,
    required this.vkRedirectUri,
    required this.yandexRedirectUri,
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

    // OAuth implicit flow (docs/20-backend/oauth.md). Client id —
    // публичный идентификатор приложения у провайдера (секреты
    // на клиенте не хранятся). Пустое значение = провайдер не
    // сконфигурирован для этой сборки → кнопка показывает
    // «скоро будет доступно» вместо входа.
    const vkAppId = String.fromEnvironment('VK_APP_ID');
    const yandexClientId = String.fromEnvironment('YANDEX_CLIENT_ID');
    // Sentinel redirect URI — WebView перехватывает навигацию на
    // него и забирает access_token из фрагмента. По умолчанию —
    // фиктивная страница на домене пользовательского клиента
    // (app.*); должен совпадать с регистрацией у провайдера.
    final oauthBase = _oauthAppBase(apiBaseUrl);
    const definedVkRedirect = String.fromEnvironment('VK_REDIRECT_URI');
    const definedYaRedirect = String.fromEnvironment('YANDEX_REDIRECT_URI');

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
      vkAppId: vkAppId,
      yandexClientId: yandexClientId,
      vkRedirectUri: definedVkRedirect.isNotEmpty
          ? definedVkRedirect
          : '$oauthBase/oauth/vk/redirect',
      yandexRedirectUri: definedYaRedirect.isNotEmpty
          ? definedYaRedirect
          : '$oauthBase/oauth/yandex/redirect',
    );
  }

  /// Базовый URL API.
  final String apiBaseUrl;

  /// Публичный id VK-приложения (`''` = OAuth через VK недоступен).
  final String vkAppId;

  /// Публичный client id Яндекс-приложения.
  final String yandexClientId;

  /// Sentinel redirect URI для VK OAuth.
  final String vkRedirectUri;

  /// Sentinel redirect URI для Yandex OAuth.
  final String yandexRedirectUri;

  /// Публичный ключ Reverb-приложения (wss://{apiHost}/app/{key}).
  final String reverbAppKey;

  /// Имя окружения: `dev`, `staging`, `prod`.
  final String environment;

  /// `true`, если приложение собрано для production.
  bool get isProduction => environment == 'prod';

  /// Хост пользовательского клиента для OAuth-sentinel страниц:
  /// `api.chtohochu.ru` → `app.chtohochu.ru` (локально →
  /// `app.chtohochu.test`). Хост без `api.`-префикса отдаётся как есть.
  static String _oauthAppBase(String apiBaseUrl) {
    final uri = Uri.tryParse(apiBaseUrl);
    if (uri == null || uri.host.isEmpty) return apiBaseUrl;
    final host = uri.host.startsWith('api.')
        ? 'app.${uri.host.substring(4)}'
        : uri.host;
    return '${uri.scheme}://$host';
  }

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
