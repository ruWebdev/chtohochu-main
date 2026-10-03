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
import '../../../session/presentation/providers/app_session_controller.dart';
import '../../domain/wish.dart';
import '../providers/wish_form_controller.dart';

/// Экран формы желания — создание и редактирование в одном компоненте.
///
/// Режимы:
/// * создание первого желания ([isFirstWish] = `true`): приветственный
///   заголовок, кнопка «Пропустить», после сохранения flow отмечается
///   пройденным;
/// * создание обычного желания: X → назад на список;
/// * редактирование ([existing] != `null`): поля предзаполнены,
///   сохранение обновляет желание и возвращает на детали.
class WishFormPage extends ConsumerStatefulWidget {
  const WishFormPage({super.key, this.isFirstWish = false, this.existing});

  final bool isFirstWish;

  /// Желание для редактирования. Если `null` — режим создания.
  final Wish? existing;

  @override
  ConsumerState<WishFormPage> createState() => _WishFormPageState();
}

class _WishFormPageState extends ConsumerState<WishFormPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _priceController;
  late final TextEditingController _linkController;
  late final TextEditingController _imageController;
  late final TextEditingController _descController;
  String? _titleError;
  String? _priceError;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final w = widget.existing;
    _titleController = TextEditingController(text: w?.title);
    _priceController = TextEditingController(text: w?.price?.toString() ?? '');
    _linkController = TextEditingController(text: w?.link);
    _imageController = TextEditingController(text: w?.imageUrl);
    _descController = TextEditingController(text: w?.description);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _linkController.dispose();
    _imageController.dispose();
    _descController.dispose();
    super.dispose();
  }

  bool _validate() {
    final l10n = context.l10n;
    final title = _titleController.text.trim();
    final priceText = _priceController.text.trim();
    String? titleError;
    String? priceError;

    if (title.isEmpty) {
      titleError = l10n.wishTitleRequired;
    } else if (title.length > 100) {
      titleError = l10n.wishTitleTooLong(100);
    }

    if (priceText.isNotEmpty &&
        int.tryParse(priceText.replaceAll(' ', '')) == null) {
      priceError = l10n.wishPriceInvalid;
    }

    setState(() {
      _titleError = titleError;
      _priceError = priceError;
    });
    return titleError == null && priceError == null;
  }

  Future<void> _save() async {
    if (!_validate()) return;

    final controller = ref.read(wishFormControllerProvider.notifier);
    final wish = await controller.save(
      title: _titleController.text.trim(),
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      price: _priceController.text.trim().isEmpty
          ? null
          : int.parse(_priceController.text.trim().replaceAll(' ', '')),
      link: _linkController.text.trim().isEmpty
          ? null
          : _linkController.text.trim(),
      imageUrl: _imageController.text.trim().isEmpty
          ? null
          : _imageController.text.trim(),
      existing: widget.existing,
    );
    if (wish == null || !mounted) return;

    // Отмечаем flow первого желания как пройденный.
    if (widget.isFirstWish) {
      await ref.read(appSessionControllerProvider.notifier).onWishCreated();
      if (!mounted) return;
      context.go(AppRoutes.home);
    } else if (_isEditing) {
      context.go(AppRoutes.wishDetails(wish.id));
    } else {
      context.go(AppRoutes.home);
    }
  }

  /// Закрыть экран без сохранения.
  ///
  /// Маршруты открываются через `context.go()`, поэтому в стеке обычно
  /// ничего нет — `pop()` не сработает. Используем `canPop()` с
  /// fallback на `go()`: при редактировании — на детали, при
  /// создании — на список.
  void _close() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    final existing = widget.existing;
    context.go(
      existing != null ? AppRoutes.wishDetails(existing.id) : AppRoutes.home,
    );
  }

  void _skip() {
    if (widget.isFirstWish) {
      ref.read(appSessionControllerProvider.notifier).skipFirstWish();
    }
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final t = AppTypography.of(context);
    final l10n = context.l10n;
    final state = ref.watch(wishFormControllerProvider);
    final isLoading = state is WishFormLoading;
    final error = state is WishFormIdle && state.error != null
        ? wishErrorMessage(l10n, state.error!)
        : null;

    return PopScope(
      // Если страница открыта через `go()`, в стеке ничего нет —
      // системный Back вернёт пользователя назад, а не закроет приложение.
      // На first-wish flow Back намеренно игнорируется (есть «Пропустить»).
      canPop: !widget.isFirstWish && context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || widget.isFirstWish) return;
        _close();
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          leading: widget.isFirstWish
              ? null
              : IconButton(
                  icon: const Icon(PhosphorIconsRegular.x),
                  tooltip: l10n.close,
                  onPressed: _close,
                ),
          actions: [
            if (widget.isFirstWish)
              TextButton(onPressed: _skip, child: Text(l10n.onboardingSkip)),
          ],
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
                  if (widget.isFirstWish) ...[
                    Icon(
                      PhosphorIconsRegular.sparkle,
                      size: 40,
                      color: colors.primary,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(l10n.firstWishTitle, style: t.screenTitle),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(l10n.firstWishDescription, style: t.secondary),
                  ] else ...[
                    Text(
                      _isEditing ? l10n.wishEditTitle : l10n.wishNewTitle,
                      style: t.screenTitle,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),

                  AppTextField(
                    controller: _titleController,
                    label: l10n.wishTitleLabel,
                    hint: l10n.wishTitleHint,
                    errorText: _titleError,
                    enabled: !isLoading,
                    autofocus: !_isEditing,
                    textInputAction: TextInputAction.next,
                    semanticsLabel: l10n.wishTitleSemantic,
                    onChanged: (_) {
                      if (_titleError != null) {
                        setState(() => _titleError = null);
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.betweenFields),
                  AppTextField(
                    controller: _priceController,
                    label: l10n.wishPriceLabel,
                    hint: l10n.wishPriceHint,
                    errorText: _priceError,
                    enabled: !isLoading,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    semanticsLabel: l10n.wishPriceSemantic,
                    onChanged: (_) {
                      if (_priceError != null) {
                        setState(() => _priceError = null);
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.betweenFields),
                  AppTextField(
                    controller: _linkController,
                    label: l10n.wishLinkLabel,
                    hint: l10n.urlHint,
                    enabled: !isLoading,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                    semanticsLabel: l10n.wishLinkSemantic,
                  ),
                  const SizedBox(height: AppSpacing.betweenFields),
                  AppTextField(
                    controller: _imageController,
                    label: l10n.wishImageLabel,
                    hint: l10n.urlHint,
                    enabled: !isLoading,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                    semanticsLabel: l10n.wishImageSemantic,
                  ),
                  const SizedBox(height: AppSpacing.betweenFields),
                  AppTextField(
                    controller: _descController,
                    label: l10n.wishNoteLabel,
                    hint: l10n.wishNoteHint,
                    maxLines: 4,
                    minLines: 2,
                    enabled: !isLoading,
                    textInputAction: TextInputAction.newline,
                    semanticsLabel: l10n.wishNoteSemantic,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  if (error != null) ...[
                    AppFeedback(type: AppFeedbackType.error, title: error),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  AppButton(
                    label: _isEditing ? l10n.saveChanges : l10n.wishSave,
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
