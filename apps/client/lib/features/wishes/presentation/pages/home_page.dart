import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/ui/ui.dart';
import '../providers/wishes_controller.dart';
import '../utils/formatters.dart';
import '../widgets/wish_card.dart';

/// Главный экран приложения — список желаний пользователя.
///
/// Состояния: загрузка, ошибка, empty state, список желаний.
/// Тап по карточке открывает детали, `+` в AppBar — создание.
/// Выход из аккаунта живёт в разделе «Профиль».
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final wishesAsync = ref.watch(wishesControllerProvider);
    final wishes = wishesAsync.value;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppShellBar(
        title: l10n.wishesTitle,
        subtitle: wishes != null && wishes.isNotEmpty
            ? wishesCountLabel(l10n, wishes.length)
            : null,
        actions: [
          AppBarAction(
            icon: PhosphorIconsRegular.plus,
            onPressed: () => context.go(AppRoutes.newWish),
            semanticLabel: l10n.wishAdd,
            tooltip: l10n.wishAdd,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(wishesControllerProvider.notifier).refresh(),
          child: wishesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AppEmptyState(
              icon: const Icon(PhosphorIconsRegular.warningCircle),
              title: l10n.loadFailed,
              description: l10n.pullToRefresh,
              action: AppButton(
                label: l10n.refresh,
                onPressed: () =>
                    ref.read(wishesControllerProvider.notifier).refresh(),
              ),
            ),
            data: (wishes) {
              if (wishes.isEmpty) {
                return ListView(
                  children: [
                    const SizedBox(height: AppSpacing.xxl),
                    AppEmptyState(
                      icon: const Icon(PhosphorIconsRegular.gift),
                      title: l10n.wishesEmptyTitle,
                      description: l10n.wishesEmptyDescription,
                      action: AppButton(
                        label: l10n.wishAddFirst,
                        leading: const Icon(PhosphorIconsRegular.plus),
                        onPressed: () => context.go(AppRoutes.newWish),
                      ),
                    ),
                  ],
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPaddingHorizontal,
                  vertical: AppSpacing.sm,
                ),
                itemCount: wishes.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.betweenCards),
                itemBuilder: (context, index) {
                  final wish = wishes[index];
                  return WishCard(
                    wish: wish,
                    onTap: () => context.go(AppRoutes.wishDetails(wish.id)),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
