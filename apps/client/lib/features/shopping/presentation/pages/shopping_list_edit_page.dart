import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/ui/ui.dart';
import '../providers/shopping_lists_controller.dart';
import 'shopping_list_form_page.dart';

/// Резолвер для маршрута `/shopping/:id/edit`.
///
/// Находит список по id в загруженном состоянии и открывает
/// [ShoppingListFormPage] в режиме редактирования.
class ShoppingListEditPage extends ConsumerWidget {
  const ShoppingListEditPage({super.key, required this.listId});

  final String listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isLoading = ref.watch(shoppingListsControllerProvider).isLoading;
    final list = ref.watch(shoppingListByIdProvider(listId));

    if (list != null) {
      return ShoppingListFormPage(existing: list);
    }

    return PopScope(
      // Страница открыта через `go()` — системный Back ведёт к списку
      // списков, а не закрывает приложение.
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go(AppRoutes.shopping);
      },
      child: Scaffold(
        backgroundColor: context.appColors.background,
        appBar: AppShellBar(
          leading: AppIconButton(
            icon: const Icon(PhosphorIconsRegular.arrowLeft),
            variant: AppIconButtonVariant.ghost,
            semanticLabel: l10n.back,
            tooltip: l10n.back,
            onPressed: () => context.go(AppRoutes.shopping),
          ),
        ),
        body: SafeArea(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : Center(
                  child: AppEmptyState(
                    icon: const Icon(PhosphorIconsRegular.magnifyingGlass),
                    title: l10n.listNotFound,
                    description: l10n.listNotFoundHint,
                    action: AppButton(
                      label: l10n.backToLists,
                      onPressed: () => context.go(AppRoutes.shopping),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
