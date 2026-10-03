import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_sizes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/ui/ui.dart';
import 'showcase_section.dart';

/// Секция: круглые icon buttons (AppBar actions).
class ShowcaseIconButtons extends StatelessWidget {
  const ShowcaseIconButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ShowcaseSubLabel('Варианты'),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: const [
            AppIconButton(
              icon: Icon(PhosphorIconsRegular.magnifyingGlass),
              tooltip: 'Поиск',
              semanticLabel: 'Поиск',
            ),
            AppIconButton(
              icon: Icon(PhosphorIconsRegular.plus),
              variant: AppIconButtonVariant.primary,
              tooltip: 'Добавить',
              semanticLabel: 'Добавить',
            ),
            AppIconButton(
              icon: Icon(PhosphorIconsRegular.bell),
              variant: AppIconButtonVariant.outline,
              tooltip: 'Уведомления',
              semanticLabel: 'Уведомления',
            ),
            AppIconButton(
              icon: Icon(PhosphorIconsRegular.gearSix),
              variant: AppIconButtonVariant.ghost,
              tooltip: 'Настройки',
              semanticLabel: 'Настройки',
            ),
            AppIconButton(
              icon: Icon(PhosphorIconsRegular.dotsThree),
              tooltip: 'Ещё',
              semanticLabel: 'Ещё',
            ),
          ],
        ),
        const ShowcaseSubLabel('Disabled'),
        const AppIconButton(
          icon: Icon(PhosphorIconsRegular.bell),
          onPressed: null,
        ),
        const ShowcaseSubLabel('Размер иконки'),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppIconButton(
              icon: const Icon(PhosphorIconsRegular.plus),
              iconSize: AppSizes.iconSizeSm,
              size: 28,
            ),
            AppIconButton(
              icon: const Icon(PhosphorIconsRegular.plus),
              iconSize: AppSizes.appBarIconSize,
            ),
            AppIconButton(
              icon: const Icon(PhosphorIconsRegular.plus),
              iconSize: AppSizes.iconSizeLg,
              size: 48,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Фон actions: ${_hex(colors.surfaceMuted)}',
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }

  String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
