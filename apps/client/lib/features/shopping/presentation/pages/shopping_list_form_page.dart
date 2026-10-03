import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/ui/ui.dart';
import '../../domain/shopping_list.dart';
import '../providers/shopping_list_form_controller.dart';

/// Экран формы списка покупок — создание и переименование
/// в одном компоненте.
///
/// Режимы:
/// * создание ([existing] = `null`): X → назад к спискам;
/// * редактирование ([existing] != `null`): поле предзаполнено,
///   сохранение возвращает на экран списка.
class ShoppingListFormPage extends ConsumerStatefulWidget {
  const ShoppingListFormPage({super.key, this.existing});

  /// Список для редактирования. Если `null` — режим создания.
  final ShoppingList? existing;

  @override
  ConsumerState<ShoppingListFormPage> createState() =>
      _ShoppingListFormPageState();
}

class _ShoppingListFormPageState extends ConsumerState<ShoppingListFormPage> {
  late final TextEditingController _titleController;
  String? _titleError;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existing?.title);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  bool _validate() {
    final l10n = context.l10n;
    final title = _titleController.text.trim();
    String? error;
    if (title.isEmpty) {
      error = l10n.listTitleRequired;
    } else if (title.length > 60) {
      error = l10n.listTitleTooLong(60);
    }
    setState(() => _titleError = error);
    return error == null;
  }

  Future<void> _save() async {
    if (!_validate()) return;
    final list = await ref
        .read(shoppingListFormControllerProvider.notifier)
        .save(title: _titleController.text.trim(), existing: widget.existing);
    if (list == null || !mounted) return;

    context.go(
      _isEditing ? AppRoutes.shoppingList(list.id) : AppRoutes.shopping,
    );
  }

  /// Закрыть без сохранения. Маршруты открываются через `go()`,
  /// поэтому в стеке обычно ничего нет — fallback на `go()`.
  void _close() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    final existing = widget.existing;
    context.go(
      existing != null
          ? AppRoutes.shoppingList(existing.id)
          : AppRoutes.shopping,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final t = AppTypography.of(context);
    final l10n = context.l10n;
    final state = ref.watch(shoppingListFormControllerProvider);
    final isLoading = state is ShoppingListFormLoading;
    final error = state is ShoppingListFormIdle && state.error != null
        ? shoppingErrorMessage(l10n, state.error!)
        : null;

    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _close();
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(PhosphorIconsRegular.x),
            tooltip: l10n.close,
            onPressed: _close,
          ),
        ),
        body: SafeArea(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPaddingHorizontal,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _isEditing ? l10n.listRename : l10n.listNewTitle,
                    style: t.screenTitle,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  AppTextField(
                    controller: _titleController,
                    label: l10n.listTitleLabel,
                    hint: l10n.listTitleHint,
                    errorText: _titleError,
                    enabled: !isLoading,
                    autofocus: !_isEditing,
                    textInputAction: TextInputAction.done,
                    semanticsLabel: l10n.listTitleLabel,
                    onSubmitted: (_) => _save(),
                    onChanged: (_) {
                      if (_titleError != null) {
                        setState(() => _titleError = null);
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  if (error != null) ...[
                    AppFeedback(type: AppFeedbackType.error, title: error),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  AppButton(
                    label: _isEditing ? l10n.saveChanges : l10n.listCreate,
                    expand: true,
                    isLoading: isLoading,
                    enabled: !isLoading,
                    leading: const Icon(PhosphorIconsRegular.check),
                    onPressed: _save,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
