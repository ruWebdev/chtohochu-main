import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_sizes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/ui/ui.dart';
import '../../../friends/domain/friend.dart';
import '../../../friends/presentation/providers/friends_controller.dart';
import '../../data/shopping_repository.dart';
import '../../domain/shopping_list_member.dart';
import '../providers/shopping_lists_controller.dart';

/// Открывает sheet управления участниками совместного списка.
///
/// Содержимое реактивно: `shoppingListByIdProvider` перечитывает
/// Drift, поэтому pending-участник появляется сразу после
/// локальной мутации, а результат pull-reconcile — после sync.
Future<void> showShoppingListMembersSheet(
  BuildContext context, {
  required String listId,
  required String currentUserId,
}) {
  return showAppBottomSheet<void>(
    context,
    title: context.l10n.listMembers,
    builder: (_) =>
        ShoppingListMembersSheet(listId: listId, currentUserId: currentUserId),
  );
}

/// Участники списка + добавление друга.
///
/// Источник кандидатов — существующий friends flow
/// (`friendsControllerProvider`): в список можно добавить только
/// друга, сервер дополнительно проверяет дружбу.
///
/// Права: owner управляет составом (add/remove), member видит
/// список участников и может только выйти сам (из экрана списка).
class ShoppingListMembersSheet extends ConsumerWidget {
  const ShoppingListMembersSheet({
    super.key,
    required this.listId,
    required this.currentUserId,
  });

  final String listId;
  final String currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = AppTypography.of(context);
    final colors = context.appColors;
    final list = ref.watch(shoppingListByIdProvider(listId));
    if (list == null) return const SizedBox.shrink();

    final isOwner = list.isOwnedBy(currentUserId);
    final members = list.members;
    final memberIds = members.map((m) => m.id).toSet();
    final friends = ref.watch(friendsControllerProvider).value ?? const [];
    final candidates = friends.where((f) => !memberIds.contains(f.id)).toList();

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final member in members) ...[
            _MemberRow(
              member: member,
              isMe: member.id == currentUserId,
              canRemove: isOwner && !member.isOwner,
              onRemove: () => _removeMember(context, ref, member),
            ),
          ],
          if (isOwner) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.listMembersAddHint,
              style: t.caption.copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: AppSpacing.xs),
            if (candidates.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Column(
                  children: [
                    Icon(
                      PhosphorIconsRegular.usersThree,
                      size: AppSizes.iconSizeLg,
                      color: colors.textMuted,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l10n.listMembersNoFriends,
                      style: t.secondary.copyWith(color: colors.textMuted),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      l10n.listMembersNoFriendsHint,
                      style: t.caption.copyWith(color: colors.textMuted),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              for (final friend in candidates)
                _CandidateRow(
                  friend: friend,
                  onAdd: () => _addMember(context, ref, friend),
                ),
          ],
        ],
      ),
    );
  }

  Future<void> _addMember(
    BuildContext context,
    WidgetRef ref,
    Friend friend,
  ) async {
    final l10n = context.l10n;
    try {
      await ref
          .read(shoppingListsControllerProvider.notifier)
          .addMember(
            listId,
            ShoppingListMember(
              id: friend.id,
              role: 'member',
              name: friend.name,
              username: friend.username,
              avatarUrl: friend.avatarUrl,
            ),
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.listMemberAdded(friend.name))),
        );
      }
    } on ShoppingError {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.listMemberAddFailed)));
      }
    }
  }

  Future<void> _removeMember(
    BuildContext context,
    WidgetRef ref,
    ShoppingListMember member,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.listMemberRemoveTitle,
      message: l10n.listMemberRemoveMessage(member.displayName),
      confirmLabel: l10n.listMemberRemove,
      destructive: true,
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref
          .read(shoppingListsControllerProvider.notifier)
          .removeMember(listId, member.id);
    } on ShoppingError {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.listMemberAddFailed)));
      }
    }
  }
}

/// Строка участника: аватар, имя/@username, роль, действие удаления.
class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.isMe,
    required this.canRemove,
    required this.onRemove,
  });

  final ShoppingListMember member;
  final bool isMe;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final t = AppTypography.of(context);
    final l10n = context.l10n;

    final role = member.isOwner
        ? l10n.listMemberOwner
        : isMe
        ? l10n.listMemberYou
        : (member.username != null ? '@${member.username}' : null);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          AppAvatar(
            imageUrl: member.avatarUrl,
            initials: member.initials,
            size: AppAvatarSize.md,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  member.displayName,
                  style: t.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (role != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    role,
                    style: t.caption.copyWith(
                      color: member.isOwner ? colors.primary : colors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (canRemove)
            AppIconButton(
              icon: const Icon(PhosphorIconsRegular.userMinus),
              variant: AppIconButtonVariant.ghost,
              semanticLabel: l10n.listMemberRemove,
              tooltip: l10n.listMemberRemove,
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}

/// Кандидат из друзей: аватар, имя, кнопка «Добавить».
class _CandidateRow extends StatelessWidget {
  const _CandidateRow({required this.friend, required this.onAdd});

  final Friend friend;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final t = AppTypography.of(context);
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
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
                  friend.name,
                  style: t.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '@${friend.username}',
                  style: t.caption.copyWith(color: colors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          AppButton(label: l10n.add, size: AppButtonSize.sm, onPressed: onAdd),
        ],
      ),
    );
  }
}
