import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/ui/ui.dart';

/// Секция: empty state.
class ShowcaseEmptyState extends StatelessWidget {
  const ShowcaseEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).extension<AppThemeColors>()!.border,
        ),
      ),
      child: const AppEmptyState(
        icon: Icon(PhosphorIconsRegular.gift),
        title: 'Здесь пока пусто',
        description: 'Добавь своё первое желание, чтобы начать.',
        action: AppButton(
          label: 'Добавить желание',
          leading: Icon(PhosphorIconsRegular.plus),
        ),
      ),
    );
  }
}
