import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_sizes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/ui/ui.dart';
import '../../../session/presentation/providers/app_session_controller.dart';
import '../../domain/wish.dart';
import '../../domain/wish_list.dart';
import '../providers/wishes_controller.dart';
import '../utils/formatters.dart';
import '../widgets/add_wish_sheet.dart';
import '../widgets/wish_card.dart';
import '../widgets/wish_list_card.dart';

/// Главный экран приложения — личный архив желаний пользователя.
///
/// Структура: секция «Мои списки» (если списки есть) + секция
/// «Мои желания» — обе двухколоночные сетки карточек.
/// Состояния: загрузка, ошибка, empty state, контент.
/// Тап по карточке желания открывает детали.
/// Sync-статус живёт микроскопично в subtitle, без баннеров.
/// Выход из аккаунта живёт в разделе «Профиль».
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final wishesAsync = ref.watch(wishesControllerProvider);
    final lists = ref.watch(wishListsProvider).value ?? const <WishList>[];
    final wishes = wishesAsync.value;
    final l10n = context.l10n;

    final syncStatus = ref.watch(syncStatusProvider);
    final pendingCount = ref.watch(pendingOutboxCountProvider).value ?? 0;
    final user = ref.watch(currentUserProvider);

    // Subtitle: «N желаний» + опциональный sync-фрагмент.
    // Состояния: idle → только count; syncing → count + микро-спиннер;
    // offline/error с pending-операциями → count + «не синхронизировано».
    String? subtitle;
    Widget? subtitleTrailing;
    if (wishes != null && wishes.isNotEmpty) {
      final count = wishesCountLabel(l10n, wishes.length);
      final notSynced =
          (syncStatus == SyncStatus.offline ||
              syncStatus == SyncStatus.error) &&
          pendingCount > 0;
      subtitle = notSynced ? '$count · ${l10n.syncNotSynced}' : count;
      if (syncStatus == SyncStatus.syncing) {
        subtitleTrailing = const _SyncIndicator();
      }
    }

    final t = AppTypography.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        // Низ не резервируем — контент уходит под стеклянный
        // bottom bar; запас в конце прокрутки даёт сам скроллер.
        bottom: false,
        child: Column(
          children: [
            // Header Row: аватар 48 + приветствие + кнопка
            // уведомлений 44 с бейджем — по референсной спеке.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPaddingHorizontal,
                AppSpacing.md,
                AppSpacing.screenPaddingHorizontal,
                0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => context.go(AppRoutes.profile),
                    child: AppAvatar(
                      imageUrl: user?.avatarUrl,
                      initials: user?.initials ?? '',
                      size: AppAvatarSize.header,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          user?.displayName ?? l10n.wishesTitle,
                          style: t.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  subtitle,
                                  style: t.secondary.copyWith(
                                    color: colors.textMuted,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              ?subtitleTrailing,
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Stack(
                    children: [
                      AppIconButton(
                        icon: const Icon(PhosphorIconsRegular.bell),
                        onPressed: () => context.go(AppRoutes.notifications),
                        semanticLabel: l10n.notificationsTitle,
                        tooltip: l10n.notificationsTitle,
                      ),
                      // Красный бейдж-точка на колокольчике.
                      Positioned(
                        top: 9,
                        right: 9,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.error,
                            border: Border.all(
                              color: colors.background,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () =>
                    ref.read(wishesControllerProvider.notifier).refresh(),
                child: wishesAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
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
                    if (wishes.isEmpty && lists.isEmpty) {
                      return ListView(
                        padding: EdgeInsets.only(
                          bottom: AppBottomBar.scrollPaddingOf(context),
                        ),
                        children: [
                          const SizedBox(height: AppSpacing.xxl),
                          AppEmptyState(
                            icon: const Icon(PhosphorIconsRegular.gift),
                            title: l10n.wishesEmptyTitle,
                            description: l10n.wishesEmptyDescription,
                            action: AppButton(
                              label: l10n.wishAddFirst,
                              leading: const Icon(PhosphorIconsRegular.plus),
                              onPressed: () => showAddWishSheet(context),
                            ),
                          ),
                        ],
                      );
                    }
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final sections = _HomeSections(
                          wishes: wishes,
                          lists: lists,
                        );
                        if (constraints.maxWidth >=
                            AppSizes.wideLayoutBreakpoint) {
                          // Wide: центрированная колонка — карточки
                          // не растягиваются на всю ширину.
                          return Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: AppSizes.contentMaxWidth,
                              ),
                              child: sections,
                            ),
                          );
                        }
                        return sections;
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

/// Ленивый контент Home: секции «Мои списки» и «Мои желания» —
/// обе двухколоночные сетки. Последний элемент — [AddWishRow].
///
/// Группировка по приоритету (единственный экран, где она есть):
/// основная группа — «Очень хочу» выше, затем «Хочу» (порядок
/// внутри групп — исходный, createdAt DESC); «Не сейчас» —
/// отдельная сворачиваемая секция ниже, пустая не показывается.
class _HomeSections extends StatefulWidget {
  const _HomeSections({required this.wishes, required this.lists});

  final List<Wish> wishes;
  final List<WishList> lists;

  @override
  State<_HomeSections> createState() => _HomeSectionsState();
}

class _HomeSectionsState extends State<_HomeSections> {
  /// «Не сейчас» свёрнута по умолчанию.
  bool _laterExpanded = false;

  /// Высота карточки списка — токен дизайн-системы (shared с
  /// WishListPage). Высота WishGridCard вычисляется от ширины —
  /// см. [WishGridCard.extentForColumnWidth].
  static const double _listCardExtent = AppSizes.wishListCardExtent;

  static const _horizontal = EdgeInsets.symmetric(
    horizontal: AppSpacing.screenPaddingHorizontal,
  );

  /// Ширина колонки двухколоночной сетки желаний.
  static double _wishColumnWidth(BuildContext context) =>
      (MediaQuery.sizeOf(context).width -
          AppSpacing.screenPaddingHorizontal * 2 -
          AppSpacing.betweenCards) /
      2;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    // Основная группа: «Очень хочу» выше обычных — внутри каждого
    // приоритета сохраняется исходный порядок (createdAt DESC).
    final main = <Wish>[
      for (final w in widget.wishes)
        if (w.priority == WishPriority.high) w,
      for (final w in widget.wishes)
        if (w.priority == WishPriority.normal) w,
    ];
    final later = [
      for (final w in widget.wishes)
        if (w.priority == WishPriority.later) w,
    ];

    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),
        if (widget.lists.isNotEmpty) ...[
          _SectionHeader(title: l10n.homeMyLists),
          _grid(
            extent: _listCardExtent,
            children: [
              for (final list in widget.lists)
                WishListCard(
                  list: list,
                  onTap: () => context.go(AppRoutes.wishList(list.id)),
                ),
            ],
          ),
        ],
        _SectionHeader(title: l10n.homeMyWishes),
        if (widget.wishes.isEmpty)
          SliverToBoxAdapter(
            child: AppEmptyState(
              icon: const Icon(PhosphorIconsRegular.gift),
              title: l10n.wishesEmptyTitle,
              description: l10n.wishesEmptyDescription,
              action: AppButton(
                label: l10n.wishAddFirst,
                leading: const Icon(PhosphorIconsRegular.plus),
                onPressed: () => showAddWishSheet(context),
              ),
            ),
          )
        else ...[
          _grid(
            extent: WishGridCard.extentForColumnWidth(
              _wishColumnWidth(context),
            ),
            children: [
              for (final wish in main)
                WishGridCard(
                  wish: wish,
                  highMarker: true,
                  onTap: () => context.go(AppRoutes.wishDetails(wish.id)),
                ),
            ],
          ),
          // «Не сейчас» — отдельная сворачиваемая секция ниже
          // основной; пустая группа не рендерится вовсе.
          if (later.isNotEmpty) ...[
            _LaterGroupHeader(
              count: later.length,
              expanded: _laterExpanded,
              onTap: () => setState(() => _laterExpanded = !_laterExpanded),
            ),
            if (_laterExpanded)
              _grid(
                extent: WishGridCard.extentForColumnWidth(
                  _wishColumnWidth(context),
                ),
                children: [
                  for (final wish in later)
                    WishGridCard(
                      wish: wish,
                      onTap: () => context.go(AppRoutes.wishDetails(wish.id)),
                    ),
                ],
              ),
          ],
        ],
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.screenPaddingHorizontal,
              right: AppSpacing.screenPaddingHorizontal,
              top: AppSpacing.betweenCards,
              bottom: AppSpacing.md,
            ),
            child: AddWishRow(),
          ),
        ),
        // Запас под floating bottom bar — последний элемент
        // списка полностью выводится из-под стекла.
        SliverToBoxAdapter(
          child: SizedBox(height: AppBottomBar.scrollPaddingOf(context)),
        ),
      ],
    );
  }

  Widget _grid({required double extent, required List<Widget> children}) {
    return SliverPadding(
      padding: _horizontal,
      sliver: SliverGrid(
        delegate: SliverChildListDelegate(children),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: AppSpacing.betweenCards,
          crossAxisSpacing: AppSpacing.betweenCards,
          mainAxisExtent: extent,
        ),
      ),
    );
  }
}

/// Заголовок секции Home («Мои списки» / «Мои желания»).
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final t = AppTypography.of(context);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(
          left: AppSpacing.screenPaddingHorizontal,
          right: AppSpacing.screenPaddingHorizontal,
          top: AppSpacing.sm,
          bottom: AppSpacing.xs,
        ),
        child: Text(
          title,
          style: t.bodyMedium.copyWith(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

/// Заголовок сворачиваемой группы «Не сейчас»: название со
/// счётчиком + chevron. Тап разворачивает/сворачивает сетку
/// отложенных желаний под ним.
class _LaterGroupHeader extends StatelessWidget {
  const _LaterGroupHeader({
    required this.count,
    required this.expanded,
    required this.onTap,
  });

  final int count;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final t = AppTypography.of(context);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(
          left: AppSpacing.screenPaddingHorizontal,
          right: AppSpacing.screenPaddingHorizontal,
          top: AppSpacing.md,
          bottom: AppSpacing.xs,
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${context.l10n.wishPriorityLater} · $count',
                  style: t.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                expanded
                    ? PhosphorIconsRegular.caretUp
                    : PhosphorIconsRegular.caretDown,
                size: AppSizes.iconSizeSm,
                color: colors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// «Слот для нового желания» — последний элемент списка.
///
/// Намеренно контрастно слабее [WishCard]: muted-фон без границы
/// и центрированный контент — выглядит как место для добавления,
/// а не как ещё одна карточка.
class AddWishRow extends StatelessWidget {
  const AddWishRow({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final t = AppTypography.of(context);
    final l10n = context.l10n;

    return Semantics(
      button: true,
      label: l10n.wishAdd,
      child: Material(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: InkWell(
          onTap: () => showAddWishSheet(context),
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: SizedBox(
            height: AppSizes.buttonHeightLg,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  PhosphorIconsRegular.plus,
                  size: AppSizes.iconSize,
                  color: colors.textMuted,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  l10n.wishAdd,
                  style: t.secondary.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Микро-индикатор синхронизации — 10px spinner после
/// разделителя «·» в subtitle AppShellBar.
class _SyncIndicator extends StatelessWidget {
  const _SyncIndicator();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final t = AppTypography.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(' · ', style: t.secondary.copyWith(color: colors.textMuted)),
        SizedBox(
          width: AppSizes.syncIndicatorSize,
          height: AppSizes.syncIndicatorSize,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: colors.textMuted,
          ),
        ),
      ],
    );
  }
}
