import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env_config.dart';
import '../constants/api_constants.dart';

/// Конфигурация Dio-клиента для API.
///
/// Feature-код НЕ должен создавать экземпляры Dio самостоятельно —
/// используется этот провайдер.
final apiClientProvider = Provider<Dio>((ref) {
  final env = EnvConfig.fromEnvironment();

  final dio = Dio(
    BaseOptions(
      baseUrl: '${env.apiBaseUrl}${ApiConstants.apiPrefix}',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );

  // Заглушка интерсептора авторизации.
  // Полная логика будет добавлена в фазе аутентификации.
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        // TODO(auth): вставлять access-токен из secure storage.
        handler.next(options);
      },
    ),
  );

  return dio;
});
