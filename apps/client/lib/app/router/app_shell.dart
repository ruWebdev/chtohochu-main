import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../features/wishes/presentation/widgets/add_wish_sheet.dart';
import '../../l10n/l10n.dart';
import '../../shared/ui/navigation/app_bottom_bar.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'routes.dart';

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
    final l10n = context.l10n;
    final currentRoute = GoRouterState.of(context).matchedLocation;

    // Центральная «+» — контекстное действие раздела.
    // Желание — quick-capture sheet; списки/друзья — свои экраны.
    final (addRoute, addLabel) = switch (currentRoute) {
      AppRoutes.shopping => (AppRoutes.newShoppingList, l10n.listAdd),
      AppRoutes.friends => (AppRoutes.friendAdd, l10n.friendAdd),
      _ => (null, l10n.wishAdd),
    };

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
            items: appBottomBarItems(l10n),
            currentRoute: currentRoute,
            onTap: (route) => context.go(route),
            centerAction: AppBottomBarCenterAction(
              icon: PhosphorIconsBold.plus,
              semanticLabel: addLabel,
              tooltip: addLabel,
              onPressed: () {
                if (addRoute == null) {
                  showAddWishSheet(context);
                } else {
                  context.go(addRoute);
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}
