import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/ui/ui.dart';
import '../providers/shopping_list_form_controller.dart';

/// Открывает sheet создания списка покупок.
///
/// Механика роута — стандартная (`showModalBottomSheet` даёт
/// barrier, back и drag-dismiss), визуальная поверхность —
/// собственный компонент [AddShoppingListSheet] в дизайн-системе.
Future<void> showAddShoppingListSheet(BuildContext context) {
  final colors = context.appColors;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: colors.scrim,
    builder: (_) => const AddShoppingListSheet(),
  );
}

/// Sheet создания списка покупок.
///
/// Одно поле — название. Список сохраняется через существующий
/// offline-first `ShoppingListFormController` → repository → outbox,
/// после успешного локального создания sheet закрывается.
class AddShoppingListSheet extends ConsumerStatefulWidget {
  const AddShoppingListSheet({super.key});

  @override
  ConsumerState<AddShoppingListSheet> createState() =>
      _AddShoppingListSheetState();
}

class _AddShoppingListSheetState extends ConsumerState<AddShoppingListSheet> {
  final TextEditingController _titleController = TextEditingController();
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    // Обновляем enabled-состояние «Создать» при вводе.
    _titleController.addListener(_onChanged);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  bool get _isDirty => _titleController.text.isNotEmpty;

  bool get _canSubmit => _titleController.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final list = await ref
        .read(shoppingListFormControllerProvider.notifier)
        .save(title: _titleController.text.trim());
    if (list == null || !mounted) return;
    // Dirty-ввод не должен блокировать программный pop и
    // триггерить discard-диалог — данные уже сохранены.
    setState(() => _allowPop = true);
    Navigator.of(context).pop();
  }

  Future<void> _confirmDiscard() async {
    final l10n = context.l10n;
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.wishDiscardTitle,
      message: l10n.wishDiscardMessage,
      confirmLabel: l10n.close,
    );
    if (confirmed == true && mounted) {
      setState(() => _allowPop = true);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final t = AppTypography.of(context);
    final l10n = context.l10n;
    final formState = ref.watch(shoppingListFormControllerProvider);
    final isLoading = formState is ShoppingListFormLoading;
    final error = formState is ShoppingListFormIdle && formState.error != null
        ? shoppingErrorMessage(l10n, formState.error!)
        : null;

    return PopScope(
      // Данные не теряем бездумно: при наличии ввода спрашиваем
      // подтверждение — действует для ×, системного Back,
      // tap по barrier и drag-down.
      canPop: !_isDirty || _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: AnimatedPadding(
        // Клавиатура поднимает sheet, не перекрывая «Создать».
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: Container(
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadii.xl),
            ),
            border: Border(
              top: BorderSide(color: colors.border.withValues(alpha: 0.6)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag indicator — визуальная метка sheet.
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.border,
                        borderRadius: BorderRadius.circular(AppRadii.full),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(child: Text(l10n.listNewTitle, style: t.title)),
                      AppIconButton(
                        icon: const Icon(PhosphorIconsRegular.x),
                        onPressed: () => Navigator.of(context).maybePop(),
                        semanticLabel: l10n.close,
                        tooltip: l10n.close,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  AppTextField(
                    controller: _titleController,
                    hint: l10n.listTitleLabel,
                    autofocus: true,
                    enabled: !isLoading,
                    textInputAction: TextInputAction.done,
                    semanticsLabel: l10n.listTitleLabel,
                    onSubmitted: (_) => _submit(),
                  ),

                  if (error != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    AppFeedback(type: AppFeedbackType.error, title: error),
                  ],

                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: l10n.listCreateAction,
                    expand: true,
                    size: AppButtonSize.lg,
                    enabled: _canSubmit && !isLoading,
                    isLoading: isLoading,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.listAddLaterHint,
                    style: t.caption.copyWith(color: colors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
