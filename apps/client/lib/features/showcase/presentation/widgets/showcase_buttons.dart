import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/ui/ui.dart';
import 'showcase_section.dart';

/// Секция: кнопки.
class ShowcaseButtons extends StatelessWidget {
  const ShowcaseButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ShowcaseSubLabel('Варианты'),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: const [
            AppButton(label: 'Primary', variant: AppButtonVariant.primary),
            AppButton(label: 'Secondary', variant: AppButtonVariant.secondary),
            AppButton(label: 'Outline', variant: AppButtonVariant.outline),
            AppButton(label: 'Ghost', variant: AppButtonVariant.ghost),
            AppButton(
              label: 'Destructive',
              variant: AppButtonVariant.destructive,
            ),
          ],
        ),
        const ShowcaseSubLabel('Размеры'),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: const [
            AppButton(label: 'Small', size: AppButtonSize.sm),
            AppButton(label: 'Medium', size: AppButtonSize.md),
            AppButton(label: 'Large', size: AppButtonSize.lg),
          ],
        ),
        const ShowcaseSubLabel('С иконкой'),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: const [
            AppButton(
              label: 'Добавить',
              leading: Icon(PhosphorIconsRegular.plus),
            ),
            AppButton(
              label: 'Поделиться',
              variant: AppButtonVariant.outline,
              leading: Icon(PhosphorIconsRegular.shareNetwork),
            ),
          ],
        ),
        const ShowcaseSubLabel('Состояния'),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: const [
            AppButton(label: 'Disabled', onPressed: null),
            AppButton(label: 'Loading', isLoading: true),
          ],
        ),
        const ShowcaseSubLabel('На всю ширину'),
        const AppButton(
          label: 'Создать желание',
          expand: true,
          leading: Icon(PhosphorIconsRegular.plus),
        ),
      ],
    );
  }
}
