import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_sizes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/ui/ui.dart';
import '../../data/wish_photo_picker.dart';
import '../providers/wish_form_controller.dart';

/// Открывает sheet быстрого добавления желания.
///
/// Механика роута — стандартная (`showModalBottomSheet` даёт
/// barrier, back и drag-dismiss), визуальная поверхность —
/// собственный компонент [AddWishSheet] в дизайн-системе.
Future<void> showAddWishSheet(BuildContext context) {
  final colors = context.appColors;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: colors.scrim,
    builder: (_) => const AddWishSheet(),
  );
}

/// Sheet быстрого добавления желания.
///
/// Capture-флоу, а не форма: одно текстовое поле, опциональные
/// URL и фото с камеры. Желание сохраняется через существующий
/// offline-first `WishFormController` → repository → outbox.
class AddWishSheet extends ConsumerStatefulWidget {
  const AddWishSheet({super.key});

  @override
  ConsumerState<AddWishSheet> createState() => _AddWishSheetState();
}

class _AddWishSheetState extends ConsumerState<AddWishSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  final List<String> _photos = [];
  bool _urlFieldVisible = false;
  String? _urlError;
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    // Обновляем enabled-состояние «Добавить» при вводе.
    _titleController.addListener(_onChanged);
    _urlController.addListener(_onChanged);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {
    if (_urlError != null) _urlError = null;
  });

  bool get _isDirty =>
      _titleController.text.isNotEmpty ||
      _urlController.text.isNotEmpty ||
      _photos.isNotEmpty;

  /// Нормализованный URL или `null` (пустой / некорректный).
  String? get _normalizedUrl {
    final v = _urlController.text.trim();
    if (v.isEmpty) return null;
    final withScheme = v.contains('://') ? v : 'https://$v';
    final uri = Uri.tryParse(withScheme);
    if (uri == null || !uri.hasAbsolutePath && uri.host.isEmpty) {
      return null;
    }
    if (uri.host.isEmpty || !uri.host.contains('.')) return null;
    return uri.toString();
  }

  bool get _canSubmit => _isDirty;

  /// Название желания: текст пользователя → хост ссылки → «Фотография».
  String _resolvedTitle(String? link) {
    final title = _titleController.text.trim();
    if (title.isNotEmpty) {
      // Backend принимает максимум 100 символов.
      return title.length > 100 ? title.substring(0, 100) : title;
    }
    if (link != null) {
      return Uri.parse(link).host;
    }
    return context.l10n.wishPhotoFallbackTitle;
  }

  Future<void> _addPhotoFromCamera() async {
    // Клавиатура убирается до открытия камеры — без борьбы
    // за focus между полем и системным экраном съёмки.
    FocusScope.of(context).unfocus();
    try {
      final path = await ref.read(wishPhotoPickerProvider).capture();
      if (path != null && mounted) {
        setState(() => _photos.add(path));
      }
    } catch (_) {
      _showPhotoError();
    }
  }

  Future<void> _addPhotosFromGallery() async {
    FocusScope.of(context).unfocus();
    try {
      final paths = await ref.read(wishPhotoPickerProvider).pickFromGallery();
      if (paths.isNotEmpty && mounted) {
        setState(() => _photos.addAll(paths));
      }
    } catch (_) {
      _showPhotoError();
    }
  }

  void _showPhotoError() {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.wishPhotoError)));
  }

  void _removePhoto(int index) => setState(() => _photos.removeAt(index));

  Future<void> _submit() async {
    final link = _normalizedUrl;
    if (_urlController.text.trim().isNotEmpty && link == null) {
      setState(() => _urlError = context.l10n.wishUrlInvalid);
      return;
    }
    if (!_canSubmit) return;

    final wish = await ref
        .read(wishFormControllerProvider.notifier)
        .save(
          title: _resolvedTitle(link),
          link: link,
          // Первое фото — primary (image_url), остальные —
          // дополнительные строки wish_images в порядке добавления.
          imageUrl: _photos.isEmpty ? null : _photos.first,
          additionalImagePaths: _photos.length > 1
              ? _photos.sublist(1)
              : const [],
        );
    if (wish == null || !mounted) return;
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
    final formState = ref.watch(wishFormControllerProvider);
    final isLoading = formState is WishFormLoading;
    final error = formState is WishFormIdle && formState.error != null
        ? wishErrorMessage(l10n, formState.error!)
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
        // Клавиатура поднимает sheet, не перекрывая «Добавить».
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
            boxShadow: context.shadowFloating,
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
                      Expanded(child: Text(l10n.wishAdd, style: t.title)),
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
                    hint: l10n.wishQuickHint,
                    autofocus: true,
                    enabled: !isLoading,
                    textInputAction: TextInputAction.done,
                    semanticsLabel: l10n.wishTitleSemantic,
                    onSubmitted: (_) => _submit(),
                  ),

                  // URL-поле появляется по нажатию «+ URL».
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    alignment: Alignment.topCenter,
                    child: _urlFieldVisible
                        ? Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.sm),
                            child: AppTextField(
                              controller: _urlController,
                              label: l10n.wishUrlLabel,
                              hint: l10n.urlHint,
                              errorText: _urlError,
                              enabled: !isLoading,
                              keyboardType: TextInputType.url,
                              textInputAction: TextInputAction.done,
                              semanticsLabel: l10n.wishUrlActionSemantic,
                              leading: const Icon(PhosphorIconsRegular.link),
                              trailing: GestureDetector(
                                onTap: () => setState(() {
                                  _urlController.clear();
                                  _urlFieldVisible = false;
                                }),
                                child: const Icon(PhosphorIconsRegular.x),
                              ),
                              onSubmitted: (_) => _submit(),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),

                  // Фото: плитки в порядке добавления.
                  if (_photos.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      height: AppSizes.sheetPhotoTileSize,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _photos.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: AppSpacing.xs),
                        itemBuilder: (context, index) => _PhotoTile(
                          path: _photos[index],
                          onRemove: () => _removePhoto(index),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.md),
                  // Вторичные источники — равная доля ширины каждой.
                  Row(
                    children: [
                      if (!_urlFieldVisible) ...[
                        Expanded(
                          child: AppButton(
                            label: l10n.wishUrlAction,
                            variant: AppButtonVariant.outline,
                            size: AppButtonSize.sm,
                            expand: true,
                            leading: const Icon(PhosphorIconsRegular.plus),
                            enabled: !isLoading,
                            onPressed: () =>
                                setState(() => _urlFieldVisible = true),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                      ],
                      Expanded(
                        child: Semantics(
                          button: true,
                          label: l10n.wishCameraActionSemantic,
                          child: AppButton(
                            label: l10n.wishCameraAction,
                            variant: AppButtonVariant.outline,
                            size: AppButtonSize.sm,
                            expand: true,
                            leading: const Icon(PhosphorIconsRegular.camera),
                            enabled: !isLoading,
                            onPressed: _addPhotoFromCamera,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Semantics(
                          button: true,
                          label: l10n.wishGalleryActionSemantic,
                          child: AppButton(
                            label: l10n.wishGalleryAction,
                            variant: AppButtonVariant.outline,
                            size: AppButtonSize.sm,
                            expand: true,
                            leading: const Icon(PhosphorIconsRegular.image),
                            enabled: !isLoading,
                            onPressed: _addPhotosFromGallery,
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (error != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    AppFeedback(type: AppFeedbackType.error, title: error),
                  ],

                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: l10n.add,
                    expand: true,
                    size: AppButtonSize.lg,
                    enabled: _canSubmit && !isLoading,
                    isLoading: isLoading,
                    leading: const Icon(PhosphorIconsRegular.plus),
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

/// Плитка добавленного фото с remove-affordance.
class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.path, required this.onRemove});

  final String path;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    const size = AppSizes.sheetPhotoTileSize;
    final l10n = context.l10n;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.md),
              child: AppImage(
                src: path,
                width: size,
                height: size,
                errorWidget: Container(
                  color: colors.surfaceMuted,
                  alignment: Alignment.center,
                  child: Icon(
                    PhosphorIconsRegular.image,
                    color: colors.textMuted,
                    size: AppSizes.iconSize,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 3,
            right: 3,
            child: Semantics(
              button: true,
              label: l10n.wishPhotoRemove,
              child: GestureDetector(
                onTap: onRemove,
                child: Tooltip(
                  message: l10n.wishPhotoRemove,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: colors.scrim,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      PhosphorIconsRegular.x,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
