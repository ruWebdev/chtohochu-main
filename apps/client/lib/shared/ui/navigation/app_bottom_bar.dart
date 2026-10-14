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
import '../buttons/app_add_action_button.dart';

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

/// Конфигурация центральной кнопки «добавить» в bottom bar.
///
/// Действие контекстное — разрешается shell'ом по текущему разделу.
class AppBottomBarCenterAction {
  const AppBottomBarCenterAction({
    required this.icon,
    required this.semanticLabel,
    this.tooltip,
    this.onPressed,
    this.color,
  });

  /// Иконка кнопки.
  final IconData icon;

  /// Семантическая метка для accessibility.
  final String semanticLabel;

  /// Тултип при долгом нажатии (опционально).
  final String? tooltip;

  /// Callback при нажатии. `null` — кнопка визуально неактивна
  /// и не выполняет действие (раздел без add-action).
  final VoidCallback? onPressed;

  /// Акцентный цвет кнопки для текущего раздела.
  /// `null` — брендовый `primary` темы.
  final Color? color;
}

/// Действия выбора в expanded-режиме центральной кнопки.
///
/// Когда заданы, обычные пункты навигации временно заменяются
/// двумя action-пилюлями по сторонам от центральной кнопки.
class AppBottomBarQuickActions {
  const AppBottomBarQuickActions({
    required this.leftLabel,
    required this.onLeft,
    required this.rightLabel,
    required this.onRight,
  });

  /// Метка левого действия.
  final String leftLabel;

  /// Callback левого действия.
  final VoidCallback onLeft;

  /// Метка правого действия.
  final String rightLabel;

  /// Callback правого действия.
  final VoidCallback onRight;
}

/// Floating bottom navigation bar в стиле Telegram.
///
/// Компактный, лёгкий, полупрозрачный элемент над контентом.
/// Не использует стандартный Material `NavigationBar`.
/// Использует backdrop blur для мягкого glassmorphism.
///
/// По центру — кнопка «добавить» в мягком гнезде. Стеклянная
/// планка центрирована на гнезде и ужата с обеих сторон: его
/// дуга чуть выступает и над верхней, и под нижней кромкой.
class AppBottomBar extends StatelessWidget {
  /// На сколько гнездо выпирает за кромку планки с каждой стороны.
  static const double _socketOverhang =
      (AppSizes.addActionSocketSize - AppSizes.bottomBarHeight) / 2;

  /// Нижний отступ для прокручиваемого контента, уходящего под бар.
  ///
  /// Внутри `AppShell` (`Scaffold.extendBody`) `padding.bottom` уже
  /// равен высоте бара вместе с системным inset; снаружи shell'а —
  /// только системному inset. Чтение из [MediaQuery.paddingOf]
  /// исключает двойной учёт при обеих навигациях Android.
  static double scrollPaddingOf(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom;

  const AppBottomBar({
    super.key,
    required this.items,
    required this.currentRoute,
    required this.onTap,
    required this.centerAction,
    this.quickActions,
  });

  /// Список пунктов навигации.
  final List<AppBottomBarItem> items;

  /// Текущий активный маршрут (для определения active state).
  final String currentRoute;

  /// Callback при нажатии на пункт.
  final ValueChanged<String> onTap;

  /// Центральная кнопка добавления (контекстное действие).
  final AppBottomBarCenterAction centerAction;

  /// Expanded-режим: пара действий вместо пунктов навигации.
  /// `null` — обычная навигация.
  final AppBottomBarQuickActions? quickActions;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final brightness = Theme.brightnessOf(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.bottomBarMarginHorizontal,
      ),
      child: SizedBox(
        // Слот по высоте гнезда — кнопка целиком остаётся
        // в hit-test зоне, планка центрирована на ней.
        height: AppSizes.addActionSocketSize,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Стеклянная планка — клипуется по форме бара.
            Positioned(
              top: _socketOverhang,
              bottom: _socketOverhang,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                  border: Border.all(
                    color: colors.border.withValues(alpha: 0.5),
                  ),
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
                    ),
                  ),
                ),
              ),
            ),
            // Пункты навигации — внутри планки.
            Positioned(
              top: _socketOverhang,
              bottom: _socketOverhang,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.bottomBarPadding,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(
                        begin: 0.94,
                        end: 1,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: quickActions == null
                      ? _navItemsRow()
                      : _quickActionsRow(quickActions!),
                ),
              ),
            ),
            // Кнопка «добавить» в гнезде — по центру слота,
            // симметрично выпирает за кромки планки.
            Positioned.fill(
              child: Center(
                child: AppAddActionButton(
                  icon: centerAction.icon,
                  semanticLabel: centerAction.semanticLabel,
                  tooltip: centerAction.tooltip,
                  color: centerAction.color,
                  onPressed: centerAction.onPressed,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Обычная строка пунктов навигации с центральным слотом-гнездом.
  Widget _navItemsRow() {
    return IgnorePointer(
      // Пока действия выбора видимы (или ещё отыгрывают
      // fade-out), пункты навигации не принимают тапы.
      ignoring: quickActions != null,
      child: Row(
        key: const ValueKey('nav-items'),
        children: [
          for (var i = 0; i < items.length; i++) ...[
            Expanded(
              child: _BottomBarItemWidget(
                item: items[i],
                isActive: _isActive(items[i].route, currentRoute),
                onTap: () => onTap(items[i].route),
              ),
            ),
            // Зарезервированный центральный слот —
            // кнопка рисуется отдельным слоем поверх.
            if (i == items.length ~/ 2 - 1)
              const SizedBox(width: AppSizes.addActionSocketSize),
          ],
        ],
      ),
    );
  }

  /// Строка действий выбора — та же геометрия: по одной
  /// компактной пилюле в каждой половине вокруг гнезда.
  Widget _quickActionsRow(AppBottomBarQuickActions actions) {
    return Row(
      key: const ValueKey('quick-actions'),
      children: [
        Expanded(
          child: Center(
            child: _QuickActionPill(
              label: actions.leftLabel,
              onTap: actions.onLeft,
            ),
          ),
        ),
        const SizedBox(width: AppSizes.addActionSocketSize),
        Expanded(
          child: Center(
            child: _QuickActionPill(
              label: actions.rightLabel,
              onTap: actions.onRight,
            ),
          ),
        ),
      ],
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? item.activeIcon : item.icon,
            size: AppSizes.bottomBarIconSize,
            color: color,
          ),
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
    );
  }
}

/// Компактная скруглённая action-пилюля expanded-режима.
///
/// Визуально — тот же «вторичный» акцент, что у выбранных
/// элементов темы (`secondary`/`secondaryForeground`).
class _QuickActionPill extends StatelessWidget {
  const _QuickActionPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final t = AppTypography.of(context);

    return Material(
      color: colors.secondary,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: SizedBox(
          height: AppSizes.buttonHeightSm,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  PhosphorIconsBold.plus,
                  size: AppSizes.iconSizeSm,
                  color: colors.secondaryForeground,
                ),
                const SizedBox(width: AppSpacing.xxs),
                Flexible(
                  child: Text(
                    label,
                    style: t.caption.copyWith(
                      color: colors.secondaryForeground,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
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
