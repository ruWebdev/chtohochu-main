import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/services/preferences_service.dart';

/// Точка входа в приложение.
///
/// `SharedPreferences` инициализируются до запуска, чтобы провайдеры
/// могли синхронно читать флаги (onboarding, first-wish flow, и т.д.).
/// `initializeDateFormatting` загружает локальные данные intl
/// (DateFormat в форматтерах) — данные встроены в приложение,
/// сеть не нужна.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru');
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const ChtoHochuApp(),
    ),
  );
}
