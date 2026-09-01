/// Конфигурация окружения приложения.
///
/// Значения передаются через `--dart-define` во время сборки.
/// Если переменная не задана, используется значение по умолчанию.
class EnvConfig {
  const EnvConfig._({required this.apiBaseUrl, required this.environment});

  /// Создаёт конфигурацию из `--dart-define` переменных.
  factory EnvConfig.fromEnvironment() {
    const apiBaseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:8000',
    );
    const environment = String.fromEnvironment(
      'ENVIRONMENT',
      defaultValue: 'dev',
    );
    return const EnvConfig._(apiBaseUrl: apiBaseUrl, environment: environment);
  }

  /// Базовый URL API.
  final String apiBaseUrl;

  /// Имя окружения: `dev`, `staging`, `prod`.
  final String environment;

  /// `true`, если приложение собрано для production.
  bool get isProduction => environment == 'prod';
}
