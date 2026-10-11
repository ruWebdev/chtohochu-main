import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/ui/ui.dart';
import '../providers/wishes_controller.dart';
import '../utils/formatters.dart';

/// Открывает sheet выбора списка для желания — вариант
/// «Без списка» + все списки пользователя.
///
/// Используется со страницы деталей желания. Мутация идёт
/// через `assignWishToList` (offline-first: локальная запись +
/// outbox, без прямого HTTP и без ожидания sync).
Future<void> showWishListPickerSheet(
  BuildContext context, {
  required String wishId,
  required String? currentListId,
}) {
  final l10n = context.l10n;
  return showAppBottomSheet<void>(
    context,
    title: currentListId == null ? l10n.wishAddToList : l10n.wishChangeList,
    builder: (_) => WishListPickerSheet(wishId: wishId),
  );
}

/// Контент sheet'а выбора списка: реактивный список
/// `wishListsProvider`, текущий список желания отмечен галочкой.
class WishListPickerSheet extends ConsumerWidget {
  const WishListPickerSheet({super.key, required this.wishId});

  final String wishId;

  Future<void> _assign(
    BuildContext context,
    WidgetRef ref,
    String? listId,
  ) async {
    try {
      await ref
          .read(wishesControllerProvider.notifier)
          .assignWishToList(wishId, listId);
      if (context.mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.errorGeneric)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final wish = ref.watch(wishByIdProvider(wishId));
    final lists = ref.watch(wishListsProvider).value ?? const [];

    // Желание удалено/недоступно — выбирать нечего.
    if (wish == null) return const SizedBox.shrink();

    Icon? checkIf(bool selected) =>
        selected ? const Icon(PhosphorIconsRegular.check) : null;

    return Flexible(
      child: ListView(
        shrinkWrap: true,
        children: [
          AppListItem(
            leading: const Icon(PhosphorIconsRegular.listDashes),
            title: l10n.wishListNone,
            selected: wish.listId == null,
            trailing: checkIf(wish.listId == null),
            onTap: () => _assign(context, ref, null),
          ),
          if (lists.isNotEmpty) const AppListDivider(),
          for (var i = 0; i < lists.length; i++) ...[
            if (i > 0) const AppListDivider(),
            AppListItem(
              leading: const Icon(PhosphorIconsRegular.listBullets),
              title: lists[i].title,
              subtitle: wishesCountLabel(l10n, lists[i].wishCount),
              selected: wish.listId == lists[i].id,
              trailing: checkIf(wish.listId == lists[i].id),
              onTap: () => _assign(context, ref, lists[i].id),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
        ],
      ),
    );
  }
}
