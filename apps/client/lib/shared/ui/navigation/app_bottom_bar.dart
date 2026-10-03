import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../app/theme/app_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_sizes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/app_typography.dart';

/// Пункт floating bottom navigation bar.
class AppBottomBarItem {
  const AppBottomBarItem({
    required this.route,
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  /// Маршрут GoRouter для перехода.
  final String route;

  /// Текстовая метка.
  final String label;

  /// Иконка в неактивном состоянии (regular weight).
  final IconData icon;

  /// Иконка в активном состоянии (bold weight).
  final IconData activeIcon;
}

/// Floating bottom navigation bar в стиле Telegram.
///
/// Компактный, лёгкий, полупрозрачный элемент над контентом.
/// Не использует стандартный Material `NavigationBar`.
/// Использует backdrop blur для мягкого glassmorphism.
class AppBottomBar extends StatelessWidget {
  const AppBottomBar({
    super.key,
    required this.items,
    required this.currentRoute,
    required this.onTap,
  });

  /// Список пунктов навигации.
  final List<AppBottomBarItem> items;

  /// Текущий активный маршрут (для определения active state).
  final String currentRoute;

  /// Callback при нажатии на пункт.
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final brightness = Theme.brightnessOf(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.bottomBarMarginHorizontal,
      ),
      child: Container(
        height: AppSizes.bottomBarHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.xl),
          border: Border.all(color: colors.border.withValues(alpha: 0.5)),
          boxShadow: context.shadowFloating,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.xl),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              color:
                  (brightness == Brightness.light
                          ? colors.surface
                          : colors.surfaceElevated)
                      .withValues(alpha: 0.82),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.bottomBarPadding,
              ),
              child: Row(
                children: items.map((item) {
                  final isActive = _isActive(item.route, currentRoute);
                  return Expanded(
                    child: _BottomBarItemWidget(
                      item: item,
                      isActive: isActive,
                      onTap: () => onTap(item.route),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Проверяет, активен ли пункт навигации.
  ///
  /// `/wishes/new` и `/first-wish` считаются частью `/home` (раздел «Что хочу»).
  bool _isActive(String itemRoute, String current) {
    if (itemRoute == AppBottomBarRoutes.home) {
      return current == AppBottomBarRoutes.home ||
          current == AppBottomBarRoutes.newWish ||
          current == AppBottomBarRoutes.firstWish;
    }
    return current == itemRoute;
  }
}

/// Маршруты, используемые bottom bar для логики active state.
class AppBottomBarRoutes {
  const AppBottomBarRoutes._();

  static const String home = '/home';
  static const String newWish = '/wishes/new';
  static const String firstWish = '/first-wish';
}

/// Виджет одного пункта bottom bar.
class _BottomBarItemWidget extends StatelessWidget {
  const _BottomBarItemWidget({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  final AppBottomBarItem item;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final t = AppTypography.of(context);
    final color = isActive ? colors.primary : colors.textMuted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? item.activeIcon : item.icon,
              size: AppSizes.bottomBarIconSize,
              color: color,
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              style: t.captionSmall.copyWith(
                color: color,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Предопределённые пункты bottom navigation bar.
///
/// Метки локализованы — список строится на месте через [l10n].
List<AppBottomBarItem> appBottomBarItems(AppLocalizations l10n) =>
    <AppBottomBarItem>[
      AppBottomBarItem(
        route: '/home',
        label: l10n.navWishes,
        icon: PhosphorIconsRegular.heart,
        activeIcon: PhosphorIconsBold.heart,
      ),
      AppBottomBarItem(
        route: '/shopping',
        label: l10n.navShopping,
        icon: PhosphorIconsRegular.shoppingCart,
        activeIcon: PhosphorIconsBold.shoppingCart,
      ),
      AppBottomBarItem(
        route: '/friends',
        label: l10n.navFriends,
        icon: PhosphorIconsRegular.users,
        activeIcon: PhosphorIconsBold.users,
      ),
      AppBottomBarItem(
        route: '/profile',
        label: l10n.navProfile,
        icon: PhosphorIconsRegular.userCircle,
        activeIcon: PhosphorIconsBold.userCircle,
      ),
    ];
