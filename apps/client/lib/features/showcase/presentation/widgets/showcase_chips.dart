import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/ui/ui.dart';
import 'showcase_section.dart';

/// Секция: chips.
class ShowcaseChips extends StatelessWidget {
  const ShowcaseChips({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ShowcaseSubLabel('Обычные'),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: const [
            AppChip(label: 'Электроника'),
            AppChip(label: 'Одежда'),
            AppChip(label: 'Книги'),
          ],
        ),
        const ShowcaseSubLabel('Selected'),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: const [
            AppChip(label: 'На день рождения', selected: true),
            AppChip(label: 'Подарки', selected: true),
          ],
        ),
        const ShowcaseSubLabel('С иконкой'),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: const [
            AppChip(
              label: 'Желание',
              leading: Icon(PhosphorIconsRegular.heart),
            ),
            AppChip(
              label: 'Поделиться',
              leading: Icon(PhosphorIconsRegular.shareNetwork),
            ),
          ],
        ),
        const ShowcaseSubLabel('Status chips'),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            AppChip(
              label: 'Доступно',
              leading: Icon(
                Icons.check_circle,
                color: colors.success,
                size: 14,
              ),
            ),
            AppChip(
              label: 'Нет в наличии',
              leading: Icon(
                Icons.cancel_outlined,
                color: colors.error,
                size: 14,
              ),
            ),
          ],
        ),
        const ShowcaseSubLabel('Disabled'),
        const AppChip(label: 'Недоступно', enabled: false),
      ],
    );
  }
}
