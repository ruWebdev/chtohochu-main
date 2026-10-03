import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/ui/ui.dart';
import 'showcase_section.dart';

/// Секция: feedback-блоки.
class ShowcaseFeedback extends StatelessWidget {
  const ShowcaseFeedback({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ShowcaseSubLabel('Success'),
        const AppFeedback(
          type: AppFeedbackType.success,
          title: 'Желание сохранено',
          description: 'Теперь оно в твоём списке «На день рождения».',
        ),
        const SizedBox(height: AppSpacing.sm),
        const ShowcaseSubLabel('Warning'),
        const AppFeedback(
          type: AppFeedbackType.warning,
          title: 'Не забудь добавить ссылку',
          description: 'Так друзьям будет проще найти подарок.',
        ),
        const SizedBox(height: AppSpacing.sm),
        const ShowcaseSubLabel('Error'),
        const AppFeedback(
          type: AppFeedbackType.error,
          title: 'Не удалось сохранить',
          description: 'Проверь подключение к интернету и попробуй снова.',
        ),
        const SizedBox(height: AppSpacing.sm),
        const ShowcaseSubLabel('Info'),
        const AppFeedback(
          type: AppFeedbackType.info,
          title: 'Поделись списком',
          description: 'Близкие увидят, что тебе действительно можно подарить.',
          icon: Icon(PhosphorIconsRegular.shareNetwork),
        ),
      ],
    );
  }
}
