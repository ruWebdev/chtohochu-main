import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';

/// Обёртка секции showcase: заголовок, описание, контент.
class ShowcaseSection extends StatelessWidget {
  const ShowcaseSection({
    super.key,
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final typography = AppTypography.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: colors.secondary,
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Text(
              title,
              style: typography.caption.copyWith(
                color: colors.secondaryForeground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(title, style: typography.sectionTitle),
          const SizedBox(height: AppSpacing.xxs),
          Text(description, style: typography.secondary),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

/// Подзаголовок внутри секции.
class ShowcaseSubLabel extends StatelessWidget {
  const ShowcaseSubLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
      child: Text(
        text,
        style: AppTypography.of(
          context,
        ).caption.copyWith(color: colors.textMuted),
      ),
    );
  }
}
