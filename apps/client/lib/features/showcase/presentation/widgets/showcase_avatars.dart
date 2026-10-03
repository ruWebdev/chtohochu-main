import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/ui/ui.dart';
import 'showcase_section.dart';

/// Секция: аватары.
class ShowcaseAvatars extends StatelessWidget {
  const ShowcaseAvatars({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ShowcaseSubLabel('Размеры'),
        Row(
          children: const [
            AppAvatar(initials: 'АН', size: AppAvatarSize.sm),
            SizedBox(width: AppSpacing.sm),
            AppAvatar(initials: 'АН', size: AppAvatarSize.md),
            SizedBox(width: AppSpacing.sm),
            AppAvatar(initials: 'АН', size: AppAvatarSize.lg),
          ],
        ),
        const ShowcaseSubLabel('С изображением (placeholder)'),
        const AppAvatar(size: AppAvatarSize.lg),
        const ShowcaseSubLabel('С индикатором статуса'),
        Row(
          children: const [
            AppAvatar(
              initials: 'АН',
              size: AppAvatarSize.md,
              showStatus: true,
              isOnline: true,
            ),
            SizedBox(width: AppSpacing.sm),
            AppAvatar(
              initials: 'МК',
              size: AppAvatarSize.md,
              showStatus: true,
              isOnline: false,
            ),
          ],
        ),
      ],
    );
  }
}
