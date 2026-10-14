import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_sizes.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/ui/ui.dart';

/// Плитка фото желания с remove-affordance.
///
/// Общий компонент для AddWishSheet и формы редактирования —
/// одна механика «квадратная миниатюра + × в углу». Источник
/// [src] — локальный путь или remote URL (разбирает `AppImage`).
/// [onRemove] == `null` — без кнопки удаления (read-only).
class WishPhotoTile extends StatelessWidget {
  const WishPhotoTile({super.key, required this.src, this.onRemove});

  final String src;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    const size = AppSizes.sheetPhotoTileSize;
    final l10n = context.l10n;
    final onRemove = this.onRemove;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.md),
              child: AppImage(
                src: src,
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
          if (onRemove != null)
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
