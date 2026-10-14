import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_sizes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/ui/ui.dart';
import '../../../sharing/presentation/share_actions.dart';
import '../../data/wish_repository.dart';
import '../../domain/wish.dart';
import '../../domain/wish_list.dart';
import '../providers/wishes_controller.dart';
import '../utils/formatters.dart';
import '../widgets/add_wish_list_sheet.dart';
import '../widgets/wish_card.dart';
import '../widgets/wish_picker_sheet.dart';

/// Экран конкретного списка желаний (WishList) — просмотр его
/// содержимого.
///
/// Данные — реактивные Drift-стримы репозитория: изменение
/// `Wish.listId` (assign/разгруппировка/pull reconcile) меняет
/// содержимое экрана автоматически, ручного refresh нет.
/// Желания открывают детали тапом — как на Home.
/// Действия над membership/списком намеренно отсутствуют.
class WishListPage extends ConsumerWidget {
  const WishListPage({super.key, required this.listId});

  final String listId;

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.home);
  }

  /// Переименование — существующий sheet списка в режиме edit.
  /// Мутация через `updateWishList` (Drift + outbox), заголовок
  /// и Home обновляются реактивно.
  Future<void> _rename(BuildContext context, WishList list) {
    return showAddWishListSheet(context, existing: list);
  }

  /// Удаление списка — подтверждение → `deleteWishList`:
  /// tombstone + ungroup желаний (`list_id` → null, сами желания
  /// не удаляются) + outbox delete. После локального удаления —
  /// возврат на Home.
  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    WishList list,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.listDeleteTitle,
      message: l10n.wishListDeleteMessage(list.title),
      confirmLabel: l10n.delete,
      destructive: true,
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(wishRepositoryProvider).deleteWishList(list.id);
      if (context.mounted) context.go(AppRoutes.home);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.errorGeneric)));
    }
  }

  /// Flat bottom sheet с действиями над списком: переименование,
  /// удаление (разделитель + красная строка — как на деталях
  /// желания).
  void _showActionsSheet(BuildContext context, WidgetRef ref, WishList list) {
    final l10n = context.l10n;
    showAppBottomSheet<void>(
      context,
      title: list.title,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppListItem(
            leading: const Icon(PhosphorIconsRegular.pencilSimple),
            title: l10n.listRenameTooltip,
            onTap: () {
              Navigator.of(sheetContext).pop();
              _rename(context, list);
            },
          ),
          const AppListDivider(),
          AppListItem(
            leading: const Icon(PhosphorIconsRegular.trash),
            title: l10n.listDeleteSemantic,
            destructive: true,
            onTap: () {
              Navigator.of(sheetContext).pop();
              _confirmDelete(context, ref, list);
            },
          ),
        ],
      ),
    );
  }

  /// Long-press по карточке → sheet с действием «Убрать из
  /// списка». Это НЕ удаление желания: `assignWishToList(null)`
  /// только сбрасывает membership, сам Wish остаётся и попадает
  /// в общий раздел на Home.
  void _openWishActions(BuildContext context, WidgetRef ref, Wish wish) {
    final l10n = context.l10n;
    showAppBottomSheet<void>(
      context,
      title: wish.title,
      builder: (sheetContext) => AppListItem(
        leading: const Icon(PhosphorIconsRegular.listDashes),
        title: l10n.wishRemoveFromList,
        onTap: () async {
          Navigator.of(sheetContext).pop();
          try {
            await ref
                .read(wishesControllerProvider.notifier)
                .assignWishToList(wish.id, null);
            if (!context.mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(l10n.wishRemovedFromList)));
          } catch (_) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(l10n.errorGeneric)));
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final l10n = context.l10n;
    final listsAsync = ref.watch(wishListsProvider);
    final list = ref.watch(wishListByIdProvider(listId));
    final wishesAsync = ref.watch(wishListWishesProvider(listId));
    final wishes = wishesAsync.value;

    return PopScope(
      // Страница открыта через `go()` — системный Back ведёт на
      // Home, а не закрывает приложение.
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _back(context);
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppShellBar(
          leading: AppIconButton(
            icon: const Icon(PhosphorIconsRegular.arrowLeft),
            variant: AppIconButtonVariant.subtle,
            semanticLabel: l10n.back,
            tooltip: l10n.back,
            onPressed: () => _back(context),
          ),
          actions: [
            if (list != null) ...[
              AppBarAction(
                icon: PhosphorIconsRegular.plus,
                onPressed: () => showWishPickerSheet(context, listId: list.id),
                semanticLabel: l10n.wishAdd,
                tooltip: l10n.wishAdd,
              ),
              // «Поделиться» — прямая кнопка бара, как на деталях.
              AppBarAction(
                icon: PhosphorIconsRegular.shareNetwork,
                onPressed: () => shareEntity(
                  context,
                  ref,
                  (api) => api.createWishListShare(list.id),
                ),
                semanticLabel: l10n.shareAction,
                tooltip: l10n.shareAction,
              ),
              // «Меню» — белая круглая кнопка, открывает flat bottom
              // sheet с действиями над списком.
              AppBarAction(
                icon: PhosphorIconsRegular.dotsThreeVertical,
                onPressed: () => _showActionsSheet(context, ref, list),
                semanticLabel: l10n.more,
                tooltip: l10n.more,
              ),
            ],
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              AppScreenTitle(
                title: list?.title,
                subtitle: list == null || wishes == null
                    ? null
                    : wishesCountLabel(l10n, wishes.length),
              ),
              Expanded(
                child: wishesAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => AppEmptyState(
                    icon: const Icon(PhosphorIconsRegular.warningCircle),
                    title: l10n.loadFailed,
                    description: l10n.pullToRefresh,
                  ),
                  data: (wishes) {
                    if (listsAsync.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (list == null) {
                      // Список удалён (локально или remote-reconcile),
                      // пока страница открыта.
                      return _NotFound(onBack: () => _back(context));
                    }
                    if (wishes.isEmpty) {
                      return const _EmptyWishes();
                    }
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final grid = _WishGrid(
                          wishes: wishes,
                          onWishLongPress: (wish) =>
                              _openWishActions(context, ref, wish),
                        );
                        if (constraints.maxWidth >=
                            AppSizes.wideLayoutBreakpoint) {
                          return Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: AppSizes.contentMaxWidth,
                              ),
                              child: grid,
                            ),
                          );
                        }
                        return grid;
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Двухколоночная сетка желаний списка — тот же `WishGridCard`
/// и тот же extent, что на Home. Long-press по карточке
/// открывает контекстные действия ([onWishLongPress]).
class _WishGrid extends StatelessWidget {
  const _WishGrid({required this.wishes, required this.onWishLongPress});

  final List<Wish> wishes;
  final ValueChanged<Wish> onWishLongPress;

  @override
  Widget build(BuildContext context) {
    final columnWidth =
        (MediaQuery.sizeOf(context).width -
            AppSpacing.screenPaddingHorizontal * 2 -
            AppSpacing.betweenCards) /
        2;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPaddingHorizontal,
            vertical: AppSpacing.sm,
          ),
          sliver: SliverGrid(
            delegate: SliverChildListDelegate([
              for (final wish in wishes)
                WishGridCard(
                  wish: wish,
                  onTap: () => context.go(AppRoutes.wishDetails(wish.id)),
                  onLongPress: () => onWishLongPress(wish),
                ),
            ]),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppSpacing.betweenCards,
              crossAxisSpacing: AppSpacing.betweenCards,
              mainAxisExtent: WishGridCard.extentForColumnWidth(columnWidth),
            ),
          ),
        ),
      ],
    );
  }
}

/// Подсказка для списка без желаний.
class _EmptyWishes extends StatelessWidget {
  const _EmptyWishes();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      children: [
        const SizedBox(height: AppSpacing.xxl),
        AppEmptyState(
          icon: const Icon(PhosphorIconsRegular.gift),
          title: l10n.wishListEmptyTitle,
          description: l10n.wishListEmptyDescription,
        ),
      ],
    );
  }
}

/// Состояние «список не найден» (удалён, пока экран открыт).
class _NotFound extends StatelessWidget {
  const _NotFound({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: AppEmptyState(
        icon: const Icon(PhosphorIconsRegular.magnifyingGlass),
        title: l10n.listNotFound,
        description: l10n.listNotFoundHint,
        action: AppButton(label: l10n.back, onPressed: onBack),
      ),
    );
  }
}
