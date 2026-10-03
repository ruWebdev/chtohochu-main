import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/ui/ui.dart';
import '../../../wishes/presentation/widgets/wish_details_body.dart';
import '../providers/friends_controller.dart';
import '../utils/friends_formatters.dart';

/// Read-only детали желания друга.
///
/// Переиспользует [WishDetailsBody] — тот же визуальный язык, что и
/// собственные детали, но без edit/delete: чужое желание нельзя
/// изменить.
class FriendWishDetailsPage extends ConsumerWidget {
  const FriendWishDetailsPage({
    super.key,
    required this.friendId,
    required this.wishId,
  });

  final String friendId;
  final String wishId;

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.friend(friendId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final l10n = context.l10n;
    final isLoading = ref.watch(friendsControllerProvider).isLoading;
    final friend = ref.watch(friendByIdProvider(friendId));
    final wish = ref.watch(friendWishByIdProvider((friendId, wishId)));

    return PopScope(
      // Страница открыта через `go()` — системный Back ведёт к профилю
      // друга, а не закрывает приложение.
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
        ),
        body: SafeArea(
          child: isLoading && wish == null
              ? const Center(child: CircularProgressIndicator())
              : wish == null
              ? _NotFound(onBack: () => _back(context))
              : WishDetailsBody(wish: wish),
        ),
      ),
    );
  }
}

/// Состояние «желание не найдено».
class _NotFound extends StatelessWidget {
  const _NotFound({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppEmptyState(
        icon: const Icon(PhosphorIconsRegular.magnifyingGlass),
        title: context.l10n.wishNotFound,
        description: context.l10n.wishNotFoundByOwner,
        action: AppButton(label: context.l10n.backToFriend, onPressed: onBack),
      ),
    );
  }
}
