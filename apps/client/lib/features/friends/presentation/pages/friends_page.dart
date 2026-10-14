import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/ui/ui.dart';
import '../providers/friends_controller.dart';
import '../utils/friends_formatters.dart';
import '../widgets/add_friend_sheet.dart';
import '../widgets/friend_card.dart';

/// Экран «Друзья» — список близких пользователя.
///
/// Ключевой сценарий: открыть друга → увидеть его желания →
/// выбрать подарок. `+` в AppBar — поиск и добавление друга.
class FriendsPage extends ConsumerWidget {
  const FriendsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final friendsAsync = ref.watch(friendsControllerProvider);
    final friends = friendsAsync.value;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppShellBar(
        actions: [
          AppBarAction(
            icon: PhosphorIconsRegular.userPlus,
            onPressed: () => showAddFriendSheet(context),
            semanticLabel: l10n.friendAdd,
            tooltip: l10n.friendAdd,
          ),
        ],
      ),
      body: SafeArea(
        // Низ не резервируем — контент уходит под стеклянный
        // bottom bar; запас в конце прокрутки даёт скроллер.
        bottom: false,
        child: Column(
          children: [
            AppScreenTitle(
              title: l10n.friendsTitle,
              subtitle: friends != null && friends.isNotEmpty
                  ? friendsCountLabel(l10n, friends.length)
                  : null,
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () =>
                    ref.read(friendsControllerProvider.notifier).refresh(),
                child: friendsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => AppEmptyState(
                    icon: const Icon(PhosphorIconsRegular.warningCircle),
                    title: l10n.loadFailed,
                    description: l10n.pullToRefresh,
                    action: AppButton(
                      label: l10n.refresh,
                      onPressed: () => ref
                          .read(friendsControllerProvider.notifier)
                          .refresh(),
                    ),
                  ),
                  data: (friends) {
                    if (friends.isEmpty) {
                      return ListView(
                        padding: EdgeInsets.only(
                          bottom: AppBottomBar.scrollPaddingOf(context),
                        ),
                        children: [
                          const SizedBox(height: AppSpacing.xxl),
                          AppEmptyState(
                            icon: const Icon(PhosphorIconsRegular.users),
                            title: l10n.friendsEmptyTitle,
                            description: l10n.friendsEmptyDescription,
                            action: AppButton(
                              label: l10n.friendAdd,
                              leading: const Icon(
                                PhosphorIconsRegular.userPlus,
                              ),
                              onPressed: () => showAddFriendSheet(context),
                            ),
                          ),
                        ],
                      );
                    }
                    return ListView.separated(
                      padding: EdgeInsets.only(
                        left: AppSpacing.screenPaddingHorizontal,
                        right: AppSpacing.screenPaddingHorizontal,
                        top: AppSpacing.sm,
                        bottom:
                            AppSpacing.sm +
                            AppBottomBar.scrollPaddingOf(context),
                      ),
                      itemCount: friends.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.betweenCards),
                      itemBuilder: (context, index) {
                        final friend = friends[index];
                        return FriendCard(
                          friend: friend,
                          onTap: () => context.go(AppRoutes.friend(friend.id)),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
