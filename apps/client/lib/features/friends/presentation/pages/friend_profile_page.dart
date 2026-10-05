import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/ui/ui.dart';
import '../../../wishes/presentation/widgets/wish_card.dart';
import '../../data/friends_repository.dart';
import '../../domain/friend.dart';
import '../providers/friends_controller.dart';
import '../utils/friends_formatters.dart';

/// Профиль друга.
///
/// Главная часть экрана — видимые желания друга (read-only).
/// Действие удаления друга — через overflow в AppBar.
class FriendProfilePage extends ConsumerWidget {
  const FriendProfilePage({super.key, required this.friendId});

  final String friendId;

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.friends);
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    Friend friend,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.friendRemoveTitle,
      message: l10n.friendRemoveMessage(friendDisplayName(l10n, friend.name)),
      confirmLabel: l10n.delete,
      destructive: true,
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref
          .read(friendsControllerProvider.notifier)
          .removeFriend(friend.id);
      if (context.mounted) context.go(AppRoutes.friends);
    } on FriendsError catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.friendRemoveFailed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final l10n = context.l10n;
    final isLoading = ref.watch(friendsControllerProvider).isLoading;
    final friend = ref.watch(friendByIdProvider(friendId));
    // Онлайн-refresh профиля и желаний в Drift; оффлайн —
    // игнорируем результат, кэш остаётся источником UI.
    ref.watch(friendDataRefreshProvider(friendId));

    return PopScope(
      // Страница открыта через `go()` — системный Back ведёт к списку
      // друзей, а не закрывает приложение.
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _back(context);
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppShellBar(
          leading: AppIconButton(
            icon: const Icon(PhosphorIconsRegular.arrowLeft),
            variant: AppIconButtonVariant.ghost,
            semanticLabel: l10n.back,
            tooltip: l10n.back,
            onPressed: () => _back(context),
          ),
          title: friend == null ? null : friendDisplayName(l10n, friend.name),
          overflowActions: [
            if (friend != null)
              AppBarAction(
                icon: PhosphorIconsRegular.userMinus,
                onPressed: () => _confirmRemove(context, ref, friend),
                semanticLabel: l10n.friendRemove,
              ),
          ],
        ),
        body: SafeArea(
          child: isLoading && friend == null
              ? const Center(child: CircularProgressIndicator())
              : friend == null
              ? _NotFound(onBack: () => _back(context))
              : _FriendBody(
                  friend: friend,
                  onWishTap: (wishId) =>
                      context.go(AppRoutes.friendWish(friend.id, wishId)),
                ),
        ),
      ),
    );
  }
}

/// Тело профиля: шапка (аватар, имя, username) + список желаний.
class _FriendBody extends StatelessWidget {
  const _FriendBody({required this.friend, required this.onWishTap});

  final Friend friend;
  final ValueChanged<String> onWishTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final t = AppTypography.of(context);
    final l10n = context.l10n;
    final wishes = friend.wishes;

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPaddingHorizontal,
      ),
      children: [
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            AppAvatar(
              imageUrl: friend.avatarUrl,
              initials: friend.initials,
              size: AppAvatarSize.lg,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(friendDisplayName(l10n, friend.name), style: t.title),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    '@${friend.username}',
                    style: t.secondary.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          wishes.isEmpty
              ? l10n.wishesSection
              : l10n.wishesSectionCount(wishes.length),
          style: t.bodyMedium.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (wishes.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: AppEmptyState(
              icon: const Icon(PhosphorIconsRegular.gift),
              title: l10n.friendWishesEmptyTitle,
              description: l10n.friendNoWishes(
                friendDisplayName(l10n, friend.name),
              ),
            ),
          )
        else ...[
          for (var i = 0; i < wishes.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.betweenCards),
            WishCard(wish: wishes[i], onTap: () => onWishTap(wishes[i].id)),
          ],
        ],
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

/// Состояние «друг не найден» (удалён, пока профиль открыт).
class _NotFound extends StatelessWidget {
  const _NotFound({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppEmptyState(
        icon: const Icon(PhosphorIconsRegular.magnifyingGlass),
        title: context.l10n.friendNotFound,
        description: context.l10n.friendNotFoundHint,
        action: AppButton(label: context.l10n.backToFriends, onPressed: onBack),
      ),
    );
  }
}
