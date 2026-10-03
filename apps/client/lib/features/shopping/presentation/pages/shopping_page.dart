import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/ui/ui.dart';
import '../providers/shopping_lists_controller.dart';
import '../utils/shopping_formatters.dart';
import '../widgets/shopping_list_card.dart';

/// Экран «Покупки» — список списков покупок.
///
/// Состояния: загрузка, ошибка, empty state, список списков.
/// Тап по карточке открывает конкретный список, `+` в AppBar —
/// создание нового списка.
class ShoppingPage extends ConsumerWidget {
  const ShoppingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final listsAsync = ref.watch(shoppingListsControllerProvider);
    final lists = listsAsync.value;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppShellBar(
        title: l10n.shoppingTitle,
        subtitle: lists != null && lists.isNotEmpty
            ? listsCountLabel(l10n, lists.length)
            : null,
        actions: [
          AppBarAction(
            icon: PhosphorIconsRegular.plus,
            onPressed: () => context.go(AppRoutes.newShoppingList),
            semanticLabel: l10n.listAdd,
            tooltip: l10n.listAdd,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(shoppingListsControllerProvider.notifier).refresh(),
          child: listsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AppEmptyState(
              icon: const Icon(PhosphorIconsRegular.warningCircle),
              title: l10n.loadFailed,
              description: l10n.pullToRefresh,
              action: AppButton(
                label: l10n.refresh,
                onPressed: () => ref
                    .read(shoppingListsControllerProvider.notifier)
                    .refresh(),
              ),
            ),
            data: (lists) {
              if (lists.isEmpty) {
                return ListView(
                  children: [
                    const SizedBox(height: AppSpacing.xxl),
                    AppEmptyState(
                      icon: const Icon(PhosphorIconsRegular.shoppingCart),
                      title: l10n.listsEmptyTitle,
                      description: l10n.listsEmptyDescription,
                      action: AppButton(
                        label: l10n.listCreate,
                        leading: const Icon(PhosphorIconsRegular.plus),
                        onPressed: () => context.go(AppRoutes.newShoppingList),
                      ),
                    ),
                  ],
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPaddingHorizontal,
                  vertical: AppSpacing.sm,
                ),
                itemCount: lists.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.betweenCards),
                itemBuilder: (context, index) {
                  final list = lists[index];
                  return ShoppingListCard(
                    list: list,
                    onTap: () => context.go(AppRoutes.shoppingList(list.id)),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
