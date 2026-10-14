import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env_config.dart';
import '../domain/oauth_provider.dart';

/// Конфигурация OAuth-провайдера для implicit token flow.
///
/// Authorize-URL строится на клиенте из публичных параметров
/// (client id — не секрет). Redirect URI — sentinel-адрес на
/// домене приложения: WebView перехватывает навигацию на него
/// и забирает `access_token` из фрагмента, сама страница
/// на сервере не обязана существовать (docs/20-backend/oauth.md).
class OAuthProviderConfig {
  const OAuthProviderConfig({
    required this.provider,
    required this.clientId,
    required this.redirectUri,
  });

  final OAuthProvider provider;

  /// Публичный идентификатор приложения у провайдера
  /// (`--dart-define=VK_APP_ID` / `YANDEX_CLIENT_ID`).
  final String clientId;

  /// Sentinel redirect URI — должен совпадать с адресом,
  /// зарегистрированным в кабинете разработчика провайдера.
  final String redirectUri;

  /// Провайдер доступен во флоу, только когда задан client id.
  /// Иначе кнопка показывает информационное «скоро будет доступно».
  bool get isConfigured => clientId.isNotEmpty;

  /// Отображаемое имя провайдера (бренд — не локализуется).
  String get label => switch (provider) {
    OAuthProvider.vk => 'VK',
    OAuthProvider.yandex => 'Яндекс',
  };

  /// Authorize-URL провайдера (implicit flow). [state] —
  /// одноразовое значение для проверки ответа на подмену.
  Uri authorizeUri({required String state}) => switch (provider) {
    OAuthProvider.vk => Uri.https('oauth.vk.com', '/authorize', {
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'response_type': 'token',
      'scope': 'email',
      'v': '5.199',
      'display': 'mobile',
      'state': state,
    }),
    OAuthProvider.yandex => Uri.https('oauth.yandex.ru', '/authorize', {
      'response_type': 'token',
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'scope': 'login:email login:info',
      'state': state,
    }),
  };
}

/// Конфигурация обоих провайдеров из окружения сборки.
final oauthProviderConfigProvider =
    Provider<Map<OAuthProvider, OAuthProviderConfig>>((ref) {
      final env = EnvConfig.fromEnvironment();
      return {
        OAuthProvider.vk: OAuthProviderConfig(
          provider: OAuthProvider.vk,
          clientId: env.vkAppId,
          redirectUri: env.vkRedirectUri,
        ),
        OAuthProvider.yandex: OAuthProviderConfig(
          provider: OAuthProvider.yandex,
          clientId: env.yandexClientId,
          redirectUri: env.yandexRedirectUri,
        ),
      };
    });
