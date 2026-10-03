import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n.dart';
import '../../shared/ui/navigation/app_bottom_bar.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// App shell для авторизованной части приложения.
///
/// Оборачивает контент раздела floating bottom navigation bar.
/// Используется через `ShellRoute` в GoRouter — каждый раздел
/// получает этот shell как родителя, bottom bar остётся на месте
/// при переключении вкладок.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  /// Контент текущего раздела.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final currentRoute = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      backgroundColor: colors.background,
      body: child,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(
            bottom: AppSpacing.bottomBarMarginBottom,
          ),
          child: AppBottomBar(
            items: appBottomBarItems(context.l10n),
            currentRoute: currentRoute,
            onTap: (route) => context.go(route),
          ),
        ),
      ),
    );
  }
}
