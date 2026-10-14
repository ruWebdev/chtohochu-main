/// OAuth-провайдер входа в приложение.
///
/// Используется всеми слоями: конфигурация (data), флоу WebView
/// (presentation) и обмен токена на backend (repository).
enum OAuthProvider { vk, yandex }

extension OAuthProviderX on OAuthProvider {
  /// Код провайдера — сегмент API-пути (`/auth/{code}`) и маркер
  /// в типизированных ошибках.
  String get code => name;
}

/// Учётные данные, полученные от OAuth-провайдера через
/// redirect-фрагмент (implicit token flow).
///
/// Держатся в памяти только на время обмена на backend — не
/// пишутся в хранилище и не логируются.
class OAuthCredentials {
  const OAuthCredentials({required this.accessToken, this.email});

  /// Access token провайдера — извлекается из фрагмента
  /// redirect-URL навигационным делегатом WebView.
  final String accessToken;

  /// Email из redirect-фрагмента VK (scope `email`): `users.get`
  /// его не возвращает, поэтому клиент передаёт адрес явно.
  /// У Яндекса в фрагменте email нет — backend получает его
  /// из профиля провайдера.
  final String? email;
}
