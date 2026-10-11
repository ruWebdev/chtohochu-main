import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/ui/ui.dart';
import '../../../../shared/utils/formatters.dart';
import '../providers/wishes_controller.dart';

/// Открывает sheet выбора существующего желания для добавления
/// в список [listId] — варианты только из несгруппированных
/// желаний (`list_id == null`): одно желание входит максимум
/// в один список.
Future<void> showWishPickerSheet(
  BuildContext context, {
  required String listId,
}) {
  return showAppBottomSheet<void>(
    context,
    title: context.l10n.wishAdd,
    builder: (_) => WishPickerSheet(listId: listId),
  );
}

/// Контент picker'а желаний: реактивный `wishesControllerProvider`
/// без желаний, уже занятых списками. Выбор → `assignWishToList`
/// (offline-first, без ожидания sync) → sheet закрывается.
class WishPickerSheet extends ConsumerWidget {
  const WishPickerSheet({super.key, required this.listId});

  final String listId;

  Future<void> _pick(BuildContext context, WidgetRef ref, String wishId) async {
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
    final wishes = (ref.watch(wishesControllerProvider).value ?? const [])
        .where((w) => w.listId == null)
        .toList();

    if (wishes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: AppEmptyState(
          icon: const Icon(PhosphorIconsRegular.gift),
          title: l10n.wishPickerEmptyTitle,
          description: l10n.wishPickerEmptyDescription,
        ),
      );
    }

    return Flexible(
      child: ListView(
        shrinkWrap: true,
        children: [
          for (var i = 0; i < wishes.length; i++) ...[
            if (i > 0) const AppListDivider(),
            AppListItem(
              leading: const Icon(PhosphorIconsRegular.gift),
              title: wishes[i].title,
              subtitle: wishes[i].price != null
                  ? formatPrice(wishes[i].price!)
                  : null,
              onTap: () => _pick(context, ref, wishes[i].id),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
        ],
      ),
    );
  }
}
