import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_sizes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/ui/ui.dart';
import '../../domain/friend.dart';
import '../providers/friends_controller.dart';
import '../utils/friends_formatters.dart';

/// Открывает sheet поиска и добавления друга.
///
/// Механика роута — стандартная (`showModalBottomSheet` даёт
/// barrier, back и drag-dismiss), визуальная поверхность —
/// собственный компонент [AddFriendSheet] в дизайн-системе.
Future<void> showAddFriendSheet(BuildContext context) {
  final colors = context.appColors;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: colors.scrim,
    builder: (_) => const AddFriendSheet(),
  );
}

/// Sheet поиска и добавления друга.
///
/// Поиск по имени или `@username`. Добавление идёт через существующий
/// offline-first `friendsControllerProvider.addFriend` → repository →
/// outbox. Состояния: initial, results, no results, already added, added.
class AddFriendSheet extends ConsumerStatefulWidget {
  const AddFriendSheet({super.key});

  @override
  ConsumerState<AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends ConsumerState<AddFriendSheet> {
  String _query = '';

  /// Debounce ввода: без него каждый символ — отдельный
  /// `GET /users/search` (спам запросов + throttle-риск).
  Timer? _debounce;

  /// Пользователи, добавленные за время жизни этого sheet'а —
  /// для состояния «Добавлен» (в отличие от «уже в друзьях»).
  final Set<String> _justAdded = {};

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = value);
    });
  }

  Future<void> _add(Friend user) async {
    FocusScope.of(context).unfocus();
    final ok = await ref
        .read(friendsControllerProvider.notifier)
        .addFriend(user);
    if (!mounted) return;
    if (ok) {
      setState(() => _justAdded.add(user.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.friendAddedSnack(
              friendDisplayName(context.l10n, user.name),
            ),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.friendAddFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final t = AppTypography.of(context);
    final l10n = context.l10n;
    final results = ref.watch(friendSearchProvider(_query));
    final friends = ref.watch(friendsControllerProvider).value ?? const [];

    // Sheet занимает основную часть экрана и ужимается над клавиатурой,
    // результаты скроллятся внутри Expanded.
    final mediaHeight = MediaQuery.sizeOf(context).height;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final sheetHeight = math.max(
      mediaHeight * 0.82 - keyboard,
      mediaHeight * 0.45,
    );

    return AnimatedPadding(
      // Клавиатура поднимает sheet, не перекрывая поле поиска.
      padding: EdgeInsets.only(bottom: keyboard),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: Container(
        height: sheetHeight,
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadii.xl),
          ),
          border: Border(
            top: BorderSide(color: colors.border.withValues(alpha: 0.6)),
          ),
          boxShadow: context.shadowFloating,
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Column(
              children: [
                // Drag indicator — визуальная метка sheet.
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.border,
                      borderRadius: BorderRadius.circular(AppRadii.full),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(child: Text(l10n.friendAdd, style: t.title)),
                    AppIconButton(
                      icon: const Icon(PhosphorIconsRegular.x),
                      onPressed: () => Navigator.of(context).maybePop(),
                      semanticLabel: l10n.close,
                      tooltip: l10n.close,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),

                AppTextField(
                  hint: l10n.friendSearchHint,
                  leading: const Icon(PhosphorIconsRegular.magnifyingGlass),
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onChanged: _onQueryChanged,
                ),
                const SizedBox(height: AppSpacing.sm),

                Expanded(
                  child: _query.trim().isEmpty
                      ? const _SearchHint()
                      : results.when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (e, _) => const _SearchError(),
                          data: (users) => users.isEmpty
                              ? _NoResults(query: _query.trim())
                              : ListView.separated(
                                  itemCount: users.length,
                                  separatorBuilder: (_, _) => const SizedBox(
                                    height: AppSpacing.betweenCards,
                                  ),
                                  itemBuilder: (context, index) {
                                    final user = users[index];
                                    final isFriend = friends.any(
                                      (f) => f.id == user.id,
                                    );
                                    return _SearchResultCard(
                                      user: user,
                                      isFriend: isFriend,
                                      justAdded: _justAdded.contains(user.id),
                                      onAdd: isFriend ? null : () => _add(user),
                                    );
                                  },
                                ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Подсказка до ввода запроса.
class _SearchHint extends StatelessWidget {
  const _SearchHint();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      children: [
        const SizedBox(height: AppSpacing.xxl),
        AppEmptyState(
          icon: const Icon(PhosphorIconsRegular.userPlus),
          title: l10n.friendSearchEmptyTitle,
          description: l10n.friendSearchEmptyDescription,
        ),
      ],
    );
  }
}

/// Ошибка поиска.
class _SearchError extends StatelessWidget {
  const _SearchError();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      children: [
        const SizedBox(height: AppSpacing.xxl),
        AppEmptyState(
          icon: const Icon(PhosphorIconsRegular.warningCircle),
          title: l10n.friendSearchFailed,
          description: l10n.tryAgain,
        ),
      ],
    );
  }
}

/// Состояние «ничего не найдено».
class _NoResults extends StatelessWidget {
  const _NoResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: AppSpacing.xxl),
        AppEmptyState(
          icon: const Icon(PhosphorIconsRegular.magnifyingGlass),
          title: context.l10n.friendSearchNoResults,
          description: context.l10n.friendSearchNoResultsHint(query),
        ),
      ],
    );
  }
}

/// Строка результата поиска: пользователь + действие «Добавить».
class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({
    required this.user,
    required this.isFriend,
    required this.justAdded,
    this.onAdd,
  });

  final Friend user;
  final bool isFriend;
  final bool justAdded;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final t = AppTypography.of(context);
    final l10n = context.l10n;

    final Widget trailing;
    if (justAdded) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            PhosphorIconsRegular.check,
            size: AppSizes.iconSizeSm,
            color: colors.success,
          ),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            l10n.friendAdded,
            style: t.caption.copyWith(color: colors.success),
          ),
        ],
      );
    } else if (isFriend) {
      trailing = Text(
        l10n.friendAlready,
        style: t.caption.copyWith(color: colors.textMuted),
      );
    } else {
      trailing = AppButton(
        label: l10n.add,
        size: AppButtonSize.sm,
        onPressed: onAdd,
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          AppAvatar(
            imageUrl: user.avatarUrl,
            initials: user.initials,
            size: AppAvatarSize.md,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  friendDisplayName(l10n, user.name),
                  style: t.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '@${user.username}',
                  style: t.caption.copyWith(color: colors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          trailing,
        ],
      ),
    );
  }
}
