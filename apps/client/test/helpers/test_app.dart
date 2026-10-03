import 'package:chtohochu/app/app.dart';
import 'package:chtohochu/core/constants/api_constants.dart';
import 'package:chtohochu/core/database/app_database.dart';
import 'package:chtohochu/core/database/database_provider.dart';
import 'package:chtohochu/core/network/api_client.dart';
import 'package:chtohochu/core/services/preferences_service.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_api.dart';

/// Инициализация mock-хранилищ для тестов.
///
/// Вызывать перед созданием приложения.
void setupTestStorage({
  Map<String, Object> preferences = const {},
  Map<String, String>? secureStorage,
}) {
  SharedPreferences.setMockInitialValues(preferences);
  // Mutable map — secure storage mock пишет в него при сохранении токенов.
  FlutterSecureStorage.setMockInitialValues(
    secureStorage ?? <String, String>{},
  );
}

/// Dio с in-memory fake API (как в [apiClientProvider], но без сети).
Dio createTestApiClient(HttpClientAdapter api) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'http://api.test${ApiConstants.apiPrefix}',
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );
  dio.httpClientAdapter = api;
  // Тот же Bearer-интерцептор, что в apiClientProvider.
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        const storage = FlutterSecureStorage();
        final token = await storage.read(key: 'access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ),
  );
  return dio;
}

/// In-memory Drift для тестов.
AppDatabase createTestDatabase() {
  // Каждый тест создаёт свою in-memory БД — warning о повторном
  // инстансе здесь безвреден.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  // closeStreamsSynchronously — иначе Drift откладывает закрытие
  // watch-стримов через Timer(0), который остаётся pending при
  // teardown widget-теста ("A Timer is still pending").
  return AppDatabase.forTesting(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );
}

/// Создаёт `ProviderScope` с переопределёнными хранилищами, БД и API,
/// обёрнутый вокруг [ChtoHochuApp].
///
/// Использование:
/// ```dart
/// final widget = await createTestApp();
/// await tester.pumpWidget(widget);
/// await tester.pumpAndSettle();
/// ```
Future<Widget> createTestApp({
  Map<String, Object> preferences = const {},
  Map<String, String>? secureStorage,
  FakeApiAdapter? api,
  AppDatabase? database,
  List<Override> overrides = const [],
}) async {
  setupTestStorage(preferences: preferences, secureStorage: secureStorage);
  // Локальные данные intl для DateFormat в форматтерах — как в main().
  await initializeDateFormatting('ru');
  final prefs = await SharedPreferences.getInstance();
  final apiAdapter = api ?? FakeApiAdapter();
  final db = database ?? createTestDatabase();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      apiClientProvider.overrideWithValue(createTestApiClient(apiAdapter)),
      appDatabaseProvider.overrideWithValue(db),
      ...overrides,
    ],
    child: const ChtoHochuApp(),
  );
}
