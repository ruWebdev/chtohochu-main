import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/preferences_service.dart';

/// Контроллер темы приложения (light/dark/system).
///
/// Загружает сохранённый режим из `SharedPreferences` при старте
/// и сохраняет изменения.
class ThemeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final prefs = ref.read(preferencesServiceProvider);
    final saved = prefs.readThemeMode();
    return switch (saved) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };
  }

  /// Переключить тему light ↔ dark.
  void toggle() {
    final next = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    set(next);
  }

  /// Установить конкретный режим и сохранить.
  void set(ThemeMode mode) {
    state = mode;
    ref.read(preferencesServiceProvider).setThemeMode(mode.name);
  }
}

/// Провайдер режима темы.
final themeModeProvider = NotifierProvider<ThemeController, ThemeMode>(
  ThemeController.new,
);
