import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_sizes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/ui/ui.dart';
import '../../../wishes/presentation/utils/formatters.dart';
import '../../domain/friend.dart';
import '../utils/friends_formatters.dart';

/// Карточка друга в списке «Друзья».
///
/// Минимум: аватар, имя, `@username · N желаний`, chevron.
/// Нет статусов, активности и социальных метрик — это не соцсеть.
class FriendCard extends StatelessWidget {
  const FriendCard({super.key, required this.friend, this.onTap});

  final Friend friend;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final t = AppTypography.of(context);
    final l10n = context.l10n;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          AppAvatar(
            imageUrl: friend.avatarUrl,
            initials: friend.initials,
            size: AppAvatarSize.md,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  friendDisplayName(l10n, friend.name),
                  style: t.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '@${friend.username} · '
                  '${wishesCountLabel(l10n, friend.wishes.length)}',
                  style: t.caption.copyWith(color: colors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Icon(
            PhosphorIconsRegular.caretRight,
            size: AppSizes.iconSizeSm,
            color: colors.textMuted,
          ),
        ],
      ),
    );
  }
}
