import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/ui/ui.dart';
import '../../data/wish_repository.dart';
import '../../domain/wish_list.dart';

/// Открывает sheet создания списка желаний — или, если передан
/// [existing], sheet переименования (та же форма и валидация).
///
/// Механика роута — стандартная (`showModalBottomSheet` даёт
/// barrier, back и drag-dismiss), визуальная поверхность —
/// собственный компонент [AddWishListSheet] в дизайн-системе.
Future<void> showAddWishListSheet(BuildContext context, {WishList? existing}) {
  final colors = context.appColors;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: colors.scrim,
    builder: (_) => AddWishListSheet(existing: existing),
  );
}

/// Sheet создания/переименования списка желаний.
///
/// Одно поле — название. Сохраняется через
/// `WishRepository.createWishList`/`updateWishList`: локальная
/// строка + outbox, до сервера довозит обычный sync. После
/// успешной локальной записи sheet закрывается. Home обновляется
/// из `watchWishLists` сам.
class AddWishListSheet extends ConsumerStatefulWidget {
  const AddWishListSheet({super.key, this.existing});

  /// Список для переименования; `null` — режим создания.
  final WishList? existing;

  @override
  ConsumerState<AddWishListSheet> createState() => _AddWishListSheetState();
}

class _AddWishListSheetState extends ConsumerState<AddWishListSheet> {
  final TextEditingController _titleController = TextEditingController();
  bool _allowPop = false;
  bool _isSubmitting = false;
  WishError? _error;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.existing?.title ?? '';
    // Обновляем enabled-состояние submit при вводе.
    _titleController.addListener(_onChanged);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  /// Dirty = ввод отличается от начального (в режиме
  /// переименования предзаполненное название dirty не даёт).
  bool get _isDirty => _titleController.text != (widget.existing?.title ?? '');

  bool get _canSubmit {
    final title = _titleController.text.trim();
    return title.isNotEmpty && title != widget.existing?.title;
  }

  Future<void> _submit() async {
    if (!_canSubmit || _isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final repo = ref.read(wishRepositoryProvider);
      final existing = widget.existing;
      if (existing == null) {
        await repo.createWishList(title: _titleController.text.trim());
      } else {
        await repo.updateWishList(
          existing.copyWith(title: _titleController.text.trim()),
        );
      }
      if (!mounted) return;
      // Dirty-ввод не должен блокировать программный pop —
      // данные уже сохранены, подтверждение не нужно.
      setState(() => _allowPop = true);
      Navigator.of(context).pop();
    } on WishError catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _error = e;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _error = const UnknownWishError();
        });
      }
    }
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
    final error = _error == null ? null : wishErrorMessage(l10n, _error!);

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
                      Expanded(
                        child: Text(
                          widget.existing == null
                              ? l10n.wishListNewTitle
                              : l10n.listRename,
                          style: t.title,
                        ),
                      ),
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
                    enabled: !_isSubmitting,
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
                    label: widget.existing == null
                        ? l10n.listCreateAction
                        : l10n.save,
                    expand: true,
                    size: AppButtonSize.lg,
                    enabled: _canSubmit && !_isSubmitting,
                    isLoading: _isSubmitting,
                    onPressed: _submit,
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
