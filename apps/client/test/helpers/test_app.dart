import 'dart:io';

import 'package:chtohochu/app/app.dart';
import 'package:chtohochu/core/constants/api_constants.dart';
import 'package:chtohochu/core/database/app_database.dart';
import 'package:chtohochu/core/database/database_provider.dart';
import 'package:chtohochu/core/media/media_upload_service.dart';
import 'package:chtohochu/core/network/api_client.dart';
import 'package:chtohochu/core/services/preferences_service.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
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
  // Не дёргать сеть за шрифтами — тестовый HttpClient возвращает 400,
  // а fetch-ошибки google_fonts считаются тестовыми исключениями.
  GoogleFonts.config.allowRuntimeFetching = false;
  _mockDocumentsDir();
}

/// `getApplicationDocumentsDirectory()` → один temp-каталог на тест.
/// Persistent media (wish photos, media/) пишется в реальную FS —
/// иначе media-миграция/сохранение фото валятся на MethodChannel.
String? _testDocsPath;
String? _testSupportPath;
void _mockDocumentsDir() {
  _testDocsPath = null;
  _testSupportPath = null;
  // createTempSync осознанно: widget-тесты работают в FakeAsync-зоне,
  // async dart:io там никогда не завершается (deadlock).
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => switch (call.method) {
          'getApplicationSupportDirectory' =>
            _testSupportPath ??= _seedFontCacheDir().path,
          _ =>
            _testDocsPath ??= Directory.systemTemp.createTempSync('docs').path,
        },
      );
}

/// Каталог app-support с «кэшем» google_fonts:
/// `<support>/OpenSans_<variant>_<hash>.ttf`.
///
/// google_fonts ищет шрифт по этому пути до HTTP-fetch. `existsSync`
/// находит файл, а последующий `readAsBytes` в FakeAsync-зоне
/// widget-тестов не завершается — загрузка молча откладывается и
/// падает fallback-шрифт. Без этого google_fonts пытается скачать
/// шрифт по сети, что считается тестовой ошибкой.
Directory _seedFontCacheDir() {
  final dir = Directory.systemTemp.createTempSync('support');
  const variants = {
    '300': '5dc92e27d06ea4a1b29131422f5047660f5872cfbb3163aae94cff6e0119d4d7',
    'regular':
        'e7d1b7879cdd87c63fcc8d266ac809e8e4af507694633638de3c89fc9120b4ab',
    '500': 'a8496c5a42a57ee2bf5fdab6e10b9258496e99f276727c7f94859f40ca39c34e',
    '600': 'e2cc496982444d203acc462da97eb2331ece503cdd07c320256710978fb4badf',
    '700': '70912d3aa6f6d974980b50d4a984b453706d6bc9708ba07f386f3b48db2aa828',
    '800': '6abf952398b1b975b6240a487842fe98cfae04b48e0958a9ce553e49ae6bb8e0',
    '300italic':
        '0ef4846c5d79fd9dcc4257c43c49b8ee954110b24eac719a1fe154d6e57ae549',
    'italic':
        'dc57d8dd7ea300c021872f3ca25a91b40de69b66c8d2a08a5889e3db21581d74',
    '500italic':
        'a14a19652281cc3fd870702e2d8e05cb13352c5c6cf33a6bf6906c55219e555a',
    '600italic':
        '945e617583caee7a409faa8751f9d47b4f6acc42252628bdcf603d53ccb6f46d',
    '700italic':
        'fe06266e3d1aceb04646f2e7811d0209f17a6d1e34db6669d011eea0a0b7a67b',
    '800italic':
        '8d53fffb3408237c918b36187187fa0c627ef24142d4d864b6441a1baf25e57d',
  };
  final bytes = File(
    'test/assets/fonts/open_sans_regular.ttf',
  ).readAsBytesSync();
  for (final entry in variants.entries) {
    File(
      '${dir.path}/OpenSans_${entry.key}_${entry.value}.ttf',
    ).writeAsBytesSync(bytes);
  }
  return dir;
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
  final dio = createTestApiClient(apiAdapter);
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      apiClientProvider.overrideWithValue(dio),
      appDatabaseProvider.overrideWithValue(db),
      // Presigned PUT не ходит в сеть и не трогает реальный FS:
      // объект регистрируется в «storage» fake-API, чтобы
      // media complete/end-to-end проходил внутри widget-теста.
      mediaUploadServiceProvider.overrideWithValue(
        MediaUploadService(
          api: dio,
          put: (url, headers, file) async => apiAdapter.markMediaObjectPut(url),
        ),
      ),
      ...overrides,
    ],
    child: const ChtoHochuApp(),
  );
}
