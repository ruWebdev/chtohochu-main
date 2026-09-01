/// Константы API.
class ApiConstants {
  const ApiConstants._();

  /// Версия API.
  static const String apiVersion = 'v1';

  /// Префикс API-эндпоинтов.
  static const String apiPrefix = '/api/$apiVersion';

  /// Заголовок авторизации.
  static const String authorizationHeader = 'Authorization';

  /// Префикс bearer-токена.
  static const String bearerPrefix = 'Bearer ';

  /// Заголовок ключа идемпотентности.
  static const String idempotencyKeyHeader = 'Idempotency-Key';
}
