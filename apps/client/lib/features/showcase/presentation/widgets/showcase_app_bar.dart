import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/ui/ui.dart';

/// AppBar для showcase с круглыми actions и переключателем темы.
class ShowcaseAppBar extends StatelessWidget {
  const ShowcaseAppBar({
    super.key,
    required this.title,
    required this.onToggleTheme,
  });

  final String title;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final typography = AppTypography.of(context);

    return Material(
      color: colors.background,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPaddingHorizontal,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Text(title, style: typography.screenTitle),
              const Spacer(),
              AppIconButton(
                icon: const Icon(PhosphorIconsRegular.magnifyingGlass),
                tooltip: 'Поиск',
                semanticLabel: 'Поиск',
                onPressed: () {},
              ),
              const SizedBox(width: AppSpacing.xs),
              AppIconButton(
                icon: const Icon(PhosphorIconsRegular.plus),
                tooltip: 'Добавить',
                semanticLabel: 'Добавить желание',
                onPressed: () {},
              ),
              const SizedBox(width: AppSpacing.xs),
              AppIconButton(
                icon: const Icon(PhosphorIconsRegular.sun),
                tooltip: 'Сменить тему',
                semanticLabel: 'Переключить тему',
                onPressed: onToggleTheme,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
