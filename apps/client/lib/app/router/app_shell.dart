import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../features/friends/presentation/widgets/add_friend_sheet.dart';
import '../../features/sharing/data/incoming_share.dart';
import '../../features/wishes/domain/wish_draft.dart';
import '../../features/shopping/presentation/widgets/add_shopping_list_sheet.dart';
import '../../features/wishes/presentation/widgets/add_wish_list_sheet.dart';
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
///
/// На разделе «Что хочу» центральная «+» не открывает sheet
/// напрямую, а разворачивает bottom bar в режим выбора действия
/// (`+ Желание` → AddWishSheet, `+ Список` → AddWishListSheet) —
/// четыре пункта навигации временно скрываются. Тап вне бара или
/// повторный тап по «+» сворачивает выбор обратно.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child});

  /// Контент текущего раздела.
  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  /// Bottom bar «Что хочу» в режиме выбора действия.
  bool _chooserOpen = false;

  @override
  void initState() {
    super.initState();
    // Share мог прийти до того, как AppShell навесил listener
    // (сессия готовилась) — проверяем уже выставленный draft.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _deliverImport(ref.read(importRequestProvider));
    });
  }

  void _deliverImport(WishDraft? draft) {
    if (draft == null) return;
    ref.read(importRequestProvider.notifier).value = null;
    // Sheet стекуется поверх текущего UI — уже открытый sheet
    // с пользовательским вводом не теряется.
    showAddWishSheet(context, draft: draft);
  }

  void _toggleChooser() => setState(() => _chooserOpen = !_chooserOpen);

  void _closeChooser() {
    if (_chooserOpen) setState(() => _chooserOpen = false);
  }

  void _openWishSheet() {
    _closeChooser();
    showAddWishSheet(context);
  }

  void _openListSheet() {
    _closeChooser();
    showAddWishListSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final l10n = context.l10n;

    // Входящий share (ACTION_SEND) после готовности сессии →
    // открываем AddWishSheet в режиме импорта.
    ref.listen(importRequestProvider, (_, draft) {
      if (draft == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _deliverImport(ref.read(importRequestProvider));
      });
    });
    final currentRoute = GoRouterState.of(context).matchedLocation;

    // Chooser живёт только на «Что хочу»: при смене маршрута
    // (редирект, programmatic navigation) он сбрасывается.
    final chooserOpen = _chooserOpen && currentRoute == AppRoutes.home;
    if (!chooserOpen) _chooserOpen = false;

    // Центральная «+» — контекстное действие раздела.
    // Желание и список — quick-capture sheets; друзья — свой экран.
    // Цвет кнопки синхронизирован с действием: каждый раздел — свой акцент,
    // Профиль — раздел без действия, кнопка приглушена.
    final (addAction, addLabel, addColor) = switch (currentRoute) {
      AppRoutes.shopping => (
        () => showAddShoppingListSheet(context),
        l10n.listAdd,
        colors.accentShopping,
      ),
      AppRoutes.friends => (
        () => showAddFriendSheet(context),
        l10n.friendAdd,
        colors.accentFriends,
      ),
      AppRoutes.profile => (null, l10n.add, colors.surfaceMuted),
      // На «Что хочу» «+» разворачивает/сворачивает выбор действия.
      _ => (_toggleChooser, l10n.wishAdd, colors.primary),
    };

    return Scaffold(
      backgroundColor: colors.background,
      // Стеклянный bottom bar полупрозрачный — body уходит под него,
      // а его высота приходит в контент через MediaQuery.padding.bottom
      // (см. AppBottomBar.scrollPaddingOf).
      extendBody: true,
      body: Stack(
        children: [
          widget.child,
          // Тап вне expanded bottom bar сворачивает выбор —
          // прозрачный слой ловит все тапы по контенту и AppBar,
          // но не перекрывает сам bottomNavigationBar.
          if (chooserOpen)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closeChooser,
                child: const SizedBox.expand(),
              ),
            ),
        ],
      ),
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
              color: addColor,
              onPressed: addAction,
            ),
            quickActions: chooserOpen
                ? AppBottomBarQuickActions(
                    leftLabel: l10n.quickAddWish,
                    onLeft: _openWishSheet,
                    rightLabel: l10n.quickAddList,
                    onRight: _openListSheet,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
