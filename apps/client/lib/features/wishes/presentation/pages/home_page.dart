import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_sizes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/ui/ui.dart';
import '../../domain/wish.dart';
import '../providers/wishes_controller.dart';
import '../utils/formatters.dart';
import '../widgets/wish_card.dart';

/// Главный экран приложения — личный архив желаний пользователя.
///
/// Состояния: загрузка, ошибка, empty state, список желаний.
/// Тап по карточке открывает детали, `+` в AppBar — создание.
/// Sync-статус живёт микроскопично в subtitle, без баннеров.
/// Выход из аккаунта живёт в разделе «Профиль».
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final wishesAsync = ref.watch(wishesControllerProvider);
    final wishes = wishesAsync.value;
    final l10n = context.l10n;

    final syncStatus = ref.watch(syncStatusProvider);
    final pendingCount = ref.watch(pendingOutboxCountProvider).value ?? 0;

    // Subtitle: «N желаний» + опциональный sync-фрагмент.
    // Состояния: idle → только count; syncing → count + микро-спиннер;
    // offline/error с pending-операциями → count + «не синхронизировано».
    String? subtitle;
    Widget? subtitleTrailing;
    if (wishes != null && wishes.isNotEmpty) {
      final count = wishesCountLabel(l10n, wishes.length);
      final notSynced =
          (syncStatus == SyncStatus.offline ||
              syncStatus == SyncStatus.error) &&
          pendingCount > 0;
      subtitle = notSynced ? '$count · ${l10n.syncNotSynced}' : count;
      if (syncStatus == SyncStatus.syncing) {
        subtitleTrailing = const _SyncIndicator();
      }
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppShellBar(
        title: l10n.wishesTitle,
        subtitle: subtitle,
        subtitleTrailing: subtitleTrailing,
        actions: [
          AppBarAction(
            icon: PhosphorIconsRegular.bell,
            onPressed: () => context.go(AppRoutes.notifications),
            semanticLabel: l10n.notificationsTitle,
            tooltip: l10n.notificationsTitle,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(wishesControllerProvider.notifier).refresh(),
          child: wishesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AppEmptyState(
              icon: const Icon(PhosphorIconsRegular.warningCircle),
              title: l10n.loadFailed,
              description: l10n.pullToRefresh,
              action: AppButton(
                label: l10n.refresh,
                onPressed: () =>
                    ref.read(wishesControllerProvider.notifier).refresh(),
              ),
            ),
            data: (wishes) {
              if (wishes.isEmpty) {
                return ListView(
                  children: [
                    const SizedBox(height: AppSpacing.xxl),
                    AppEmptyState(
                      icon: const Icon(PhosphorIconsRegular.gift),
                      title: l10n.wishesEmptyTitle,
                      description: l10n.wishesEmptyDescription,
                      action: AppButton(
                        label: l10n.wishAddFirst,
                        leading: const Icon(PhosphorIconsRegular.plus),
                        onPressed: () => context.go(AppRoutes.newWish),
                      ),
                    ),
                  ],
                );
              }
              return LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= AppSizes.wideLayoutBreakpoint) {
                    // Wide: центрированная колонка + 2-column grid,
                    // карточки не растягиваются на всю ширину.
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: AppSizes.contentMaxWidth,
                        ),
                        child: _WishGrid(wishes: wishes),
                      ),
                    );
                  }
                  return _WishList(wishes: wishes);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Одноколоночный ленивый список желаний (телефон).
/// Последний элемент — [AddWishRow].
class _WishList extends StatelessWidget {
  const _WishList({required this.wishes});

  final List<Wish> wishes;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.only(
        left: AppSpacing.screenPaddingHorizontal,
        right: AppSpacing.screenPaddingHorizontal,
        top: AppSpacing.sm,
        bottom: AppSpacing.md,
      ),
      itemCount: wishes.length + 1,
      separatorBuilder: (_, _) =>
          const SizedBox(height: AppSpacing.betweenCards),
      itemBuilder: (context, index) {
        if (index == wishes.length) return const AddWishRow();
        final wish = wishes[index];
        return WishCard(
          wish: wish,
          onTap: () => context.go(AppRoutes.wishDetails(wish.id)),
        );
      },
    );
  }
}

/// Двухколоночный ленивый grid желаний (tablet / landscape ≥ 600px).
/// Карточки фиксированной высоты, AddWishRow — во всю ширину под grid.
class _WishGrid extends StatelessWidget {
  const _WishGrid({required this.wishes});

  final List<Wish> wishes;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.only(
            left: AppSpacing.screenPaddingHorizontal,
            right: AppSpacing.screenPaddingHorizontal,
            top: AppSpacing.sm,
          ),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate((context, index) {
              final wish = wishes[index];
              return WishCard(
                wish: wish,
                onTap: () => context.go(AppRoutes.wishDetails(wish.id)),
              );
            }, childCount: wishes.length),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppSpacing.betweenCards,
              crossAxisSpacing: AppSpacing.betweenCards,
              mainAxisExtent: AppSizes.wishThumbSize + AppSpacing.sm * 2,
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.screenPaddingHorizontal,
              right: AppSpacing.screenPaddingHorizontal,
              top: AppSpacing.betweenCards,
              bottom: AppSpacing.md,
            ),
            child: AddWishRow(),
          ),
        ),
      ],
    );
  }
}

/// «Слот для нового желания» — последний элемент списка.
///
/// Намеренно контрастно слабее [WishCard]: muted-фон без границы
/// и центрированный контент — выглядит как место для добавления,
/// а не как ещё одна карточка.
class AddWishRow extends StatelessWidget {
  const AddWishRow({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final t = AppTypography.of(context);
    final l10n = context.l10n;

    return Semantics(
      button: true,
      label: l10n.wishAdd,
      child: Material(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: InkWell(
          onTap: () => context.go(AppRoutes.newWish),
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: SizedBox(
            height: AppSizes.buttonHeightLg,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  PhosphorIconsRegular.plus,
                  size: AppSizes.iconSize,
                  color: colors.textMuted,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  l10n.wishAdd,
                  style: t.secondary.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Микро-индикатор синхронизации — 10px spinner после
/// разделителя «·» в subtitle AppShellBar.
class _SyncIndicator extends StatelessWidget {
  const _SyncIndicator();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final t = AppTypography.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(' · ', style: t.secondary.copyWith(color: colors.textMuted)),
        SizedBox(
          width: AppSizes.syncIndicatorSize,
          height: AppSizes.syncIndicatorSize,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: colors.textMuted,
          ),
        ),
      ],
    );
  }
}
