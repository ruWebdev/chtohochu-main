import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/ui/ui.dart';
import '../../../sharing/presentation/share_actions.dart';
import '../../data/wish_repository.dart';
import '../../domain/wish.dart';
import '../providers/wishes_controller.dart';
import '../widgets/wish_details_body.dart';
import '../widgets/wish_list_picker_sheet.dart';

/// Экран деталей желания.
///
/// Открывается по тапу на карточку в списке. Показывает желание
/// целиком: изображение, название, цену, ссылку, заметку, дату.
/// Действия: редактирование и удаление (с подтверждением).
class WishDetailsPage extends ConsumerWidget {
  const WishDetailsPage({super.key, required this.wishId});

  final String wishId;

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.home);
  }

  /// Flat bottom sheet с действиями над желанием:
  /// редактирование, добавление в список, удаление.
  void _showActionsSheet(BuildContext context, WidgetRef ref, Wish wish) {
    final l10n = context.l10n;
    showAppBottomSheet<void>(
      context,
      title: wish.title,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppListItem(
            leading: const Icon(PhosphorIconsRegular.pencilSimple),
            title: l10n.edit,
            onTap: () {
              Navigator.of(sheetContext).pop();
              context.go(AppRoutes.wishEdit(wish.id));
            },
          ),
          AppListItem(
            leading: const Icon(PhosphorIconsRegular.listPlus),
            title: wish.listId == null
                ? l10n.wishAddToList
                : l10n.wishChangeList,
            onTap: () {
              Navigator.of(sheetContext).pop();
              showWishListPickerSheet(
                context,
                wishId: wish.id,
                currentListId: wish.listId,
              );
            },
          ),
          const AppListDivider(),
          AppListItem(
            leading: const Icon(PhosphorIconsRegular.trash),
            title: l10n.delete,
            destructive: true,
            onTap: () {
              Navigator.of(sheetContext).pop();
              _confirmDelete(context, ref, wish);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Wish wish,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.wishDeleteTitle,
      message: l10n.wishDeleteMessage,
      confirmLabel: l10n.delete,
      destructive: true,
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(wishesControllerProvider.notifier).deleteWish(wish.id);
      if (context.mounted) context.go(AppRoutes.home);
    } on WishError catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.wishDeleteFailed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final l10n = context.l10n;
    final isLoading = ref.watch(wishesControllerProvider).isLoading;
    final wish = ref.watch(wishByIdProvider(wishId));
    final wishListId = wish?.listId;
    final list = wishListId == null
        ? null
        : ref.watch(wishListByIdProvider(wishListId));

    return PopScope(
      // Страница открыта через `go()` — системный Back ведёт к списку
      // желаний, а не закрывает приложение.
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
            if (wish != null) ...[
              // «Поделиться» — сейчас вызывает существующий share-link
              // (mock-уровень визуала, логика та же).
              AppBarAction(
                icon: PhosphorIconsRegular.shareNetwork,
                onPressed: () => shareEntity(
                  context,
                  ref,
                  (api) => api.createWishShare(wish.id),
                ),
                semanticLabel: l10n.shareAction,
                tooltip: l10n.shareAction,
              ),
              // «Меню» — белая круглая кнопка, открывает flat bottom
              // sheet с действиями над желанием.
              AppBarAction(
                icon: PhosphorIconsRegular.dotsThreeVertical,
                onPressed: () => _showActionsSheet(context, ref, wish),
                semanticLabel: l10n.more,
                tooltip: l10n.more,
              ),
            ],
          ],
        ),
        body: SafeArea(
          child: isLoading && wish == null
              ? const Center(child: CircularProgressIndicator())
              : wish == null
              ? _NotFound(onBack: () => _back(context))
              : WishDetailsBody(
                  wish: wish,
                  additionalImages:
                      ref.watch(wishImagesProvider(wishId)).value ?? const [],
                  // Блок membership: «Без списка» или название списка.
                  // Тап всегда открывает sheet выбора списка.
                  // Пока списки грузятся — блок скрыт, чтобы не
                  // мигать неверным состоянием.
                  listTitle: wish.listId == null
                      ? l10n.wishListNone
                      : list?.title,
                  inList: wish.listId != null,
                  onListTap: () => showWishListPickerSheet(
                    context,
                    wishId: wish.id,
                    currentListId: wish.listId,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Состояние «желание не найдено» (например, удалено пока открыто).
class _NotFound extends StatelessWidget {
  const _NotFound({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: AppEmptyState(
        icon: const Icon(PhosphorIconsRegular.magnifyingGlass),
        title: l10n.wishNotFound,
        description: l10n.wishNotFoundHint,
        action: AppButton(label: l10n.backToList, onPressed: onBack),
      ),
    );
  }
}
