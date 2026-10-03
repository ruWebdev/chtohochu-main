import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../shared/ui/ui.dart';
import 'showcase_section.dart';

/// Секция: dialog / bottom sheet.
class ShowcaseDialogs extends StatelessWidget {
  const ShowcaseDialogs({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ShowcaseSubLabel('Диалоги'),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            AppButton(
              label: 'Информация',
              variant: AppButtonVariant.secondary,
              onPressed: () => showAppInfoDialog(
                context,
                title: 'Поделиться списком',
                message:
                    'Близкие увидят твои желания и смогут выбрать, что подарить.',
              ),
            ),
            AppButton(
              label: 'Подтверждение',
              variant: AppButtonVariant.secondary,
              onPressed: () async {
                final ok = await showAppConfirmDialog(
                  context,
                  title: 'Удалить желание?',
                  message: 'Действие нельзя отменить.',
                  confirmLabel: 'Удалить',
                  destructive: true,
                );
                if (ok == true && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Желание удалено')),
                  );
                }
              },
            ),
          ],
        ),
        const ShowcaseSubLabel('Bottom sheet'),
        AppButton(
          label: 'Открыть sheet',
          variant: AppButtonVariant.secondary,
          onPressed: () => showAppBottomSheet(
            context,
            title: 'Добавить желание',
            builder: (sheetContext) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                AppTextField(hint: 'Что ты хочешь?'),
                SizedBox(height: 12),
                AppButton(
                  label: 'Сохранить',
                  expand: true,
                  leading: Icon(PhosphorIconsRegular.check),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
