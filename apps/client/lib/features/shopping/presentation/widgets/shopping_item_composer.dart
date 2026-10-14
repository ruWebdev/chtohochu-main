import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_sizes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/ui/ui.dart';
import '../../data/shopping_photo_picker.dart';

/// Composer добавления позиции в список покупок.
///
/// Постоянный input bar внизу экрана в стиле мессенджера:
/// attachment-кнопка (Камера/Галерея) слева, многострочное поле
/// по центру, компактная кнопка отправки справа.
///
/// Позицию можно добавить: только текстом, только фото или
/// текст + фото (одно). Отправка идёт через [onSubmit] —
/// существующий offline-first `addItem` репозитория.
class ShoppingItemComposer extends ConsumerStatefulWidget {
  const ShoppingItemComposer({super.key, required this.onSubmit});

  /// Локальное создание позиции. Возвращает `true` при успехе —
  /// тогда composer очищает текст и сбрасывает фото.
  final Future<bool> Function(String title, String? imagePath) onSubmit;

  @override
  ConsumerState<ShoppingItemComposer> createState() =>
      _ShoppingItemComposerState();
}

class _ShoppingItemComposerState extends ConsumerState<ShoppingItemComposer> {
  final TextEditingController _controller = TextEditingController();
  String? _photo;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSubmit => _controller.text.trim().isNotEmpty || _photo != null;

  Future<void> _pickImage() async {
    final l10n = context.l10n;
    FocusScope.of(context).unfocus();
    final source = await showAppBottomSheet<String>(
      context,
      title: l10n.itemPhotoAttach,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppButton(
            label: l10n.wishCameraAction,
            variant: AppButtonVariant.outline,
            expand: true,
            leading: const Icon(PhosphorIconsRegular.camera),
            onPressed: () => Navigator.of(sheetContext).pop('camera'),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: l10n.wishGalleryAction,
            variant: AppButtonVariant.outline,
            expand: true,
            leading: const Icon(PhosphorIconsRegular.image),
            onPressed: () => Navigator.of(sheetContext).pop('gallery'),
          ),
        ],
      ),
    );
    if (source == null || !mounted) return;
    try {
      final picker = ref.read(shoppingPhotoPickerProvider);
      final path = source == 'camera'
          ? await picker.capture()
          : (await picker.pickFromGallery()).firstOrNull;
      if (path != null && mounted) {
        setState(() => _photo = path);
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

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final ok = await widget.onSubmit(_controller.text.trim(), _photo);
    if (ok && mounted) {
      setState(() {
        _controller.clear();
        _photo = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_photo != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: _PhotoPreview(
                path: _photo!,
                onRemove: () => setState(() => _photo = null),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          Row(
            // Кнопки прибиты к нижней кромке — как в мессенджерах:
            // при росте поля до 4 строк они остаются на месте.
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AppIconButton(
                icon: const Icon(PhosphorIconsRegular.paperclip),
                variant: AppIconButtonVariant.subtle,
                onPressed: _pickImage,
                semanticLabel: l10n.itemPhotoAttach,
                tooltip: l10n.itemPhotoAttach,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Container(
                  // Input-плашка: одна строка ≈ высоте кнопок (36),
                  // рост до 4 строк вверх при неизменной оси кнопок.
                  constraints: const BoxConstraints(
                    minHeight: AppSizes.iconButtonSize,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    border: Border.all(color: colors.border),
                  ),
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: l10n.itemComposerHint,
                      // Тема задаёт filled/surface + minHeight 48 —
                      // здесь плашку рисует контейнер, поле прозрачное.
                      filled: false,
                      constraints: const BoxConstraints(),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                    ),
                    style: AppTypography.of(context).body,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              AppIconButton(
                icon: const Icon(PhosphorIconsRegular.paperPlaneTilt),
                variant: AppIconButtonVariant.primary,
                onPressed: _canSubmit ? _submit : null,
                semanticLabel: l10n.add,
                tooltip: l10n.add,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Маленькое превью выбранного фото внутри composer с remove-кнопкой.
class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({required this.path, required this.onRemove});

  final String path;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    const size = AppSizes.sheetPhotoTileSize;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.md),
            child: SizedBox(
              width: size,
              height: size,
              child: AppImage(
                src: path,
                fit: BoxFit.cover,
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
              label: context.l10n.wishPhotoRemove,
              child: GestureDetector(
                onTap: onRemove,
                child: Tooltip(
                  message: context.l10n.wishPhotoRemove,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: colors.scrim,
                      borderRadius: BorderRadius.circular(AppRadii.xs),
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
