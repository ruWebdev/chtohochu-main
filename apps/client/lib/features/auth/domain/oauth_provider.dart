/// OAuth-провайдер входа в приложение.
///
/// Используется всеми слоями: конфигурация (data), флоу WebView
/// (presentation) и обмен на backend (repository).
enum OAuthProvider { vk, yandex }

extension OAuthProviderX on OAuthProvider {
  /// Код провайдера — сегмент API-пути (`/auth/{code}`) и маркер
  /// в типизированных ошибках.
  String get code => name;

  /// Схема обмена: VK ID работает по authorization code + PKCE
  /// (implicit-токены VK привязаны к IP устройства и не годятся
  /// для серверного вызова), Яндекс — implicit access_token
  /// из фрагмента.
  bool get usesCodeFlow => this == OAuthProvider.vk;
}

/// Данные от OAuth-провайдера, полученные перехватом redirect-URL
/// в WebView ([OAuthPage]).
///
/// Заполнены одни из двух наборов, по схеме провайдера:
/// * code flow (VK): [code], [deviceId], [codeVerifier], [state];
/// * implicit (Yandex): [accessToken], [state].
///
/// Держатся в памяти только на время обмена на backend — не
/// пишутся в хранилище и не логируются.
class OAuthCredentials {
  const OAuthCredentials({
    this.accessToken,
    this.code,
    this.deviceId,
    this.codeVerifier,
    this.state,
  });

  /// Implicit access_token (Яндекс).
  final String? accessToken;

  /// Authorization code (VK).
  final String? code;

  /// device_id из redirect-URL (VK).
  final String? deviceId;

  /// PKCE-verifier, сгенерированный до открытия authorize-URL (VK).
  final String? codeVerifier;

  /// state, проверенный при перехвате — передаётся backend для
  /// обмена кода (VK требует его в запросе обмена).
  final String? state;
}
