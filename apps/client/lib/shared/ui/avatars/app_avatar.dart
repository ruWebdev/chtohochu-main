import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_sizes.dart';
import '../../../app/theme/app_spacing.dart';

/// Размер аватара.
enum AppAvatarSize {
  sm(AppSizes.avatarSm),
  md(AppSizes.avatarMd),
  lg(AppSizes.avatarLg);

  const AppAvatarSize(this.value);
  final double value;
}

/// Аватар приложения.
///
/// Показывает изображение, если задано `imageUrl`, иначе инициалы или
/// placeholder. Опционально — индикатор статуса (online).
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    this.imageUrl,
    this.initials,
    this.size = AppAvatarSize.md,
    this.showStatus = false,
    this.isOnline = false,
  });

  final String? imageUrl;
  final String? initials;
  final AppAvatarSize size;
  final bool showStatus;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final diameter = size.value;
    final statusDot = diameter * 0.28;

    final avatar = Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: imageUrl != null
          ? Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              width: diameter,
              height: diameter,
              errorBuilder: (_, _, _) => _placeholder(colors),
            )
          : _placeholder(colors),
    );

    if (!showStatus) return avatar;

    return SizedBox(
      width: diameter,
      height: diameter,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: statusDot,
              height: statusDot,
              decoration: BoxDecoration(
                color: isOnline ? colors.success : colors.textMuted,
                shape: BoxShape.circle,
                border: Border.all(color: colors.background, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(AppThemeColors colors) {
    final text = (initials ?? '').trim().isEmpty ? '?' : initials!.trim();
    final fontSize = diameter * 0.4;
    return Text(
      text,
      style: TextStyle(
        color: colors.textSecondary,
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  double get diameter => size.value;
}

/// Расширение для удобного доступа к padding аватара в layout.
extension AppAvatarSpacing on AppAvatar {
  /// Отступ между аватаром и текстом.
  double get gap => switch (size) {
    AppAvatarSize.sm => AppSpacing.xs,
    AppAvatarSize.md => AppSpacing.sm,
    AppAvatarSize.lg => AppSpacing.md,
  };
}
