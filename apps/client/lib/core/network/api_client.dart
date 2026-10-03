import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env_config.dart';
import '../constants/api_constants.dart';
import '../services/secure_storage_service.dart';

/// Конфигурация Dio-клиента для API.
///
/// Feature-код НЕ должен создавать экземпляры Dio самостоятельно —
/// используется этот провайдер.
final apiClientProvider = Provider<Dio>((ref) {
  final env = EnvConfig.fromEnvironment();
  final secureStorage = ref.read(secureStorageServiceProvider);

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
      // 4xx/5xx — не исключения уровня transport; SyncEngine и
      // репозитории разбирают status code сами через DioException.
    ),
  );

  // Bearer-токен из secure storage на каждый запрос.
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await secureStorage.readAccessToken();
        if (token != null) {
          options.headers[ApiConstants.authorizationHeader] =
              '${ApiConstants.bearerPrefix}$token';
        }
        handler.next(options);
      },
    ),
  );

  return dio;
});
