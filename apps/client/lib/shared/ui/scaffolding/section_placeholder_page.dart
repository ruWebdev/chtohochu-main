import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/ui/ui.dart';

/// Аккуратный placeholder-экран для разделов, которые ещё не реализованы.
///
/// Не выглядит как техническая заглушка — соответствует визуальному
/// языку приложения: [AppShellBar], заголовок раздела, empty state.
class SectionPlaceholderPage extends StatelessWidget {
  const SectionPlaceholderPage({
    super.key,
    required this.title,
    required this.icon,
    required this.message,
    this.actions = const [],
  });

  /// Заголовок раздела в AppBar.
  final String title;

  /// Иконка раздела.
  final IconData icon;

  /// Текст placeholder-сообщения.
  final String message;

  /// Контекстные action-кнопки для AppBar.
  final List<AppBarAction> actions;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppShellBar(title: title, actions: actions),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: AppEmptyState(
              icon: Icon(icon),
              title: title,
              description: message,
            ),
          ),
        ),
      ),
    );
  }
}
