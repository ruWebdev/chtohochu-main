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
import '../../../../l10n/l10n.dart';
import '../../../../shared/ui/ui.dart';
import '../../data/shopping_repository.dart';
import '../../domain/shopping_item.dart';
import '../../domain/shopping_list.dart';
import '../providers/shopping_lists_controller.dart';
import '../widgets/shopping_item_composer.dart';
import '../widgets/shopping_item_row.dart';

/// Экран конкретного списка покупок — позиции списка.
///
/// Позиции: тап переключает «куплено», свайп удаляет, долгое нажатие
/// открывает редактирование (название + количество). Внизу — постоянный
/// composer добавления позиции (текст и/или одно фото).
/// Actions: переименовать список, удалить список.
class ShoppingListPage extends ConsumerStatefulWidget {
  const ShoppingListPage({super.key, required this.listId});

  final String listId;

  @override
  ConsumerState<ShoppingListPage> createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends ConsumerState<ShoppingListPage> {
  void _back() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.shopping);
  }

  Future<void> _confirmDeleteList(ShoppingList list) async {
    final l10n = context.l10n;
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.listDeleteTitle,
      message: l10n.listDeleteMessage(list.title),
      confirmLabel: l10n.delete,
      destructive: true,
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(shoppingListsControllerProvider.notifier)
          .deleteList(list.id);
      if (mounted) context.go(AppRoutes.shopping);
    } on ShoppingError catch (e) {
      if (mounted) _showMutationError(e);
    }
  }

  /// Выполнить мутацию списка и показать ошибку, если она не удалась.
  ///
  /// Ошибки репозитория не должны проглатываться молча — пользователь
  /// должен видеть, что действие не сохранилось.
  Future<void> _runMutation(Future<void> Function() action) async {
    try {
      await action();
    } on ShoppingError catch (e) {
      if (mounted) _showMutationError(e);
    }
  }

  void _showMutationError(ShoppingError error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(shoppingErrorMessage(context.l10n, error))),
    );
  }

  /// Локальное создание позиции из composer. Возвращает `true` при
  /// успехе — тогда composer очищает ввод. Фото-only позиция получает
  /// fallback-название (backend требует непустой title).
  Future<bool> _submitItem(String title, String? imagePath) async {
    try {
      await ref
          .read(shoppingListsControllerProvider.notifier)
          .addItem(
            widget.listId,
            title: title.isEmpty ? context.l10n.wishPhotoFallbackTitle : title,
            imagePath: imagePath,
          );
      return true;
    } on ShoppingError catch (e) {
      if (mounted) _showMutationError(e);
      return false;
    }
  }

  Future<void> _openItemActions(ShoppingList list, ShoppingItem item) async {
    await showAppBottomSheet<void>(
      context,
      title: context.l10n.itemSheetTitle,
      builder: (sheetContext) {
        return _ItemEditForm(
          item: item,
          onSave: (title, quantity) async {
            try {
              await ref
                  .read(shoppingListsControllerProvider.notifier)
                  .updateItem(
                    list.id,
                    item.id,
                    title: title,
                    quantity: quantity,
                  );
              if (sheetContext.mounted) Navigator.of(sheetContext).pop();
            } on ShoppingError catch (e) {
              if (mounted) _showMutationError(e);
            }
          },
          onDelete: () async {
            try {
              await ref
                  .read(shoppingListsControllerProvider.notifier)
                  .deleteItem(list.id, item.id);
              if (sheetContext.mounted) Navigator.of(sheetContext).pop();
            } on ShoppingError catch (e) {
              if (mounted) _showMutationError(e);
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final l10n = context.l10n;
    final isLoading = ref.watch(shoppingListsControllerProvider).isLoading;
    final list = ref.watch(shoppingListByIdProvider(widget.listId));

    return PopScope(
      // Страница открыта через `go()` — системный Back ведёт к списку
      // списков, а не закрывает приложение.
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _back();
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppShellBar(
          leading: AppIconButton(
            icon: const Icon(PhosphorIconsRegular.arrowLeft),
            variant: AppIconButtonVariant.ghost,
            semanticLabel: l10n.back,
            tooltip: l10n.back,
            onPressed: _back,
          ),
          actions: [
            if (list != null) ...[
              AppBarAction(
                icon: PhosphorIconsRegular.pencilSimple,
                onPressed: () =>
                    context.go(AppRoutes.shoppingListEdit(list.id)),
                semanticLabel: l10n.listRename,
                tooltip: l10n.listRenameTooltip,
              ),
              AppBarAction(
                icon: PhosphorIconsRegular.trash,
                onPressed: () => _confirmDeleteList(list),
                semanticLabel: l10n.listDeleteSemantic,
                tooltip: l10n.listDeleteSemantic,
              ),
            ],
          ],
        ),
        // Composer — в конце body, а не bottomNavigationBar: Scaffold
        // уменьшает именно body над viewInsets (resizeToAvoidBottomInset),
        // а bottomNavigationBar раскладывается по полной высоте экрана
        // и перекрывается клавиатурой.
        body: SafeArea(
          child: isLoading && list == null
              ? const Center(child: CircularProgressIndicator())
              : list == null
              ? _NotFound(onBack: _back)
              : Column(
                  children: [
                    Expanded(child: _buildList(context, list)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenPaddingHorizontal,
                        AppSpacing.xs,
                        AppSpacing.screenPaddingHorizontal,
                        AppSpacing.sm,
                      ),
                      child: ShoppingItemComposer(onSubmit: _submitItem),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, ShoppingList list) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPaddingHorizontal,
          vertical: AppSpacing.sm,
        ),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          _ListHeader(list: list),
          const SizedBox(height: AppSpacing.md),

          if (list.items.isEmpty)
            const _EmptyItems()
          else
            for (var i = 0; i < list.items.length; i++) ...[
              // Тонкий разделитель, выровненный с началом названия
              // (padding строки + превью 40 + gap).
              if (i > 0)
                const AppListDivider(
                  indent: AppSpacing.xs + 40 + AppSpacing.sm,
                ),
              ShoppingItemRow(
                key: ValueKey(list.items[i].id),
                item: list.items[i],
                onToggle: () => _runMutation(
                  () => ref
                      .read(shoppingListsControllerProvider.notifier)
                      .toggleItem(list.id, list.items[i].id),
                ),
                onDelete: () => _runMutation(
                  () => ref
                      .read(shoppingListsControllerProvider.notifier)
                      .deleteItem(list.id, list.items[i].id),
                ),
                onLongPress: () => _openItemActions(list, list.items[i]),
              ),
            ],

          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

/// Заголовок списка: название + прогресс покупок.
class _ListHeader extends StatelessWidget {
  const _ListHeader({required this.list});

  final ShoppingList list;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final t = AppTypography.of(context);
    final l10n = context.l10n;
    final total = list.items.length;
    final checked = list.checkedCount;
    final allDone = total > 0 && checked == total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(list.title, style: t.title),
        const SizedBox(height: AppSpacing.xs),
        Text(
          allDone
              ? l10n.listAllDone
              : total == 0
              ? l10n.listEmpty
              : l10n.listProgress(checked, total),
          style: t.caption.copyWith(
            color: allDone ? colors.success : colors.textMuted,
          ),
        ),
        if (total > 0) ...[
          const SizedBox(height: AppSpacing.sm),
          _ProgressBar(value: total == 0 ? 0 : checked / total),
        ],
      ],
    );
  }
}

/// Тонкий прогресс-бар в токенах дизайн-системы.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final done = value >= 1;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.full),
      child: SizedBox(
        height: 4,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: colors.surfaceMuted)),
            FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              child: ColoredBox(color: done ? colors.success : colors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Подсказка для списка без позиций.
class _EmptyItems extends StatelessWidget {
  const _EmptyItems();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final t = AppTypography.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: [
          Icon(
            PhosphorIconsRegular.basket,
            size: AppSizes.iconSizeLg,
            color: colors.textMuted,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.l10n.listEmptyItems,
            style: t.secondary.copyWith(color: colors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Форма редактирования позиции внутри bottom sheet.
///
/// Позволяет изменить название и количество, а также удалить позицию —
/// альтернатива swipe для тех, кто не открыл жест.
class _ItemEditForm extends StatefulWidget {
  const _ItemEditForm({
    required this.item,
    required this.onSave,
    required this.onDelete,
  });

  final ShoppingItem item;
  final Future<void> Function(String title, int quantity) onSave;
  final Future<void> Function() onDelete;

  @override
  State<_ItemEditForm> createState() => _ItemEditFormState();
}

class _ItemEditFormState extends State<_ItemEditForm> {
  late final TextEditingController _titleController;
  late final TextEditingController _quantityController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item.title);
    _quantityController = TextEditingController(
      text: widget.item.quantity.toString(),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final quantity =
        int.tryParse(_quantityController.text.trim()) ?? widget.item.quantity;
    if (title.isEmpty || _saving) return;
    setState(() => _saving = true);
    // onSave при ошибке показывает feedback и не закрывает sheet —
    // кнопка не должна остаться в loading.
    await widget.onSave(title, quantity < 1 ? 1 : quantity);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          controller: _titleController,
          label: l10n.itemNameLabel,
          autofocus: true,
          textInputAction: TextInputAction.next,
          semanticsLabel: l10n.itemNameLabel,
        ),
        const SizedBox(height: AppSpacing.betweenFields),
        AppTextField(
          controller: _quantityController,
          label: l10n.itemQuantityLabel,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          semanticsLabel: l10n.itemQuantityLabel,
          onSubmitted: (_) => _save(),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            AppButton(
              label: l10n.delete,
              variant: AppButtonVariant.destructive,
              onPressed: _saving ? null : () => widget.onDelete(),
            ),
            const Spacer(),
            AppButton(label: l10n.save, isLoading: _saving, onPressed: _save),
          ],
        ),
      ],
    );
  }
}

/// Состояние «список не найден» (например, удалён пока открыт).
class _NotFound extends StatelessWidget {
  const _NotFound({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppEmptyState(
        icon: const Icon(PhosphorIconsRegular.magnifyingGlass),
        title: context.l10n.listNotFound,
        description: context.l10n.listNotFoundHint,
        action: AppButton(label: context.l10n.backToLists, onPressed: onBack),
      ),
    );
  }
}
