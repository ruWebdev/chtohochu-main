import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_sizes.dart';
import '../../../app/theme/app_spacing.dart';

/// Тип feedback-блока.
enum AppFeedbackType { success, warning, error, info }

/// Feedback-блок: мягкий цветной блок с иконкой, заголовком и описанием.
///
/// [compact] — однострочный вариант для второстепенных сообщений:
/// меньший padding, иконка 16px, текст bodySmall в одну строку.
class AppFeedback extends StatelessWidget {
  const AppFeedback({
    super.key,
    required this.type,
    required this.title,
    this.description,
    this.icon,
    this.compact = false,
  });

  final AppFeedbackType type;
  final String title;
  final String? description;
  final Widget? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppThemeColors>()!;
    final typography = theme.textTheme;

    final (accent, surface, defaultIcon) = switch (type) {
      AppFeedbackType.success => (
        colors.success,
        colors.successSurface,
        Icons.check_circle_outline,
      ),
      AppFeedbackType.warning => (
        colors.warning,
        colors.warningSurface,
        Icons.warning_amber_outlined,
      ),
      AppFeedbackType.error => (
        colors.error,
        colors.errorSurface,
        Icons.error_outline,
      ),
      AppFeedbackType.info => (
        colors.info,
        colors.infoSurface,
        Icons.info_outline,
      ),
    };

    final Widget content = compact
        ? Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: typography.bodySmall!.copyWith(color: accent),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: typography.titleMedium!.copyWith(color: accent),
              ),
              if (description != null) ...[
                const SizedBox(height: 2),
                Text(
                  description!,
                  style: typography.bodySmall!.copyWith(color: accent),
                ),
              ],
            ],
          );

    return Container(
      padding: compact
          ? const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            )
          : const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Row(
        crossAxisAlignment: compact
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          IconTheme.merge(
            data: IconThemeData(
              color: accent,
              size: compact ? AppSizes.iconSizeSm : AppSizes.iconSizeLg,
            ),
            child: icon != null ? icon! : Icon(defaultIcon),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: content),
        ],
      ),
    );
  }
}
