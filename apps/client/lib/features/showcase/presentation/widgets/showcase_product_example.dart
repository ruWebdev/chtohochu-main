import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_sizes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/ui/ui.dart';

/// Секция: пример реального экрана «ЧтоХочу».
///
/// Демонстрирует, как дизайн-система работает в продукте, а не в изоляции.
class ShowcaseProductExample extends StatelessWidget {
  const ShowcaseProductExample({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final t = AppTypography.of(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AppBar
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPaddingHorizontal,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Text('ЧтоХочу', style: t.screenTitle),
                const Spacer(),
                _Action(icon: const Icon(PhosphorIconsRegular.magnifyingGlass)),
                const SizedBox(width: AppSpacing.xs),
                _Action(icon: const Icon(PhosphorIconsRegular.plus)),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPaddingHorizontal,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Привет, Анна 👋', style: t.bodyMedium),
                const SizedBox(height: AppSpacing.xxs),
                Text('Мои желания', style: t.sectionTitle),
                const SizedBox(height: AppSpacing.md),
                // Chips — списки
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: const [
                    AppChip(label: 'Все', selected: true),
                    AppChip(label: 'На день рождения'),
                    AppChip(label: 'Подарки'),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                // Wish cards
                const _WishCard(
                  title: 'Беспроводные наушники',
                  subtitle: 'Sony WH-1000XM6',
                  meta: '34 990 ₽',
                ),
                const SizedBox(height: AppSpacing.betweenCards),
                const _WishCard(
                  title: 'Книга по фотографии',
                  subtitle: 'Сьюзан Сонтаг',
                  meta: '2 490 ₽',
                  reserved: true,
                ),
                const SizedBox(height: AppSpacing.betweenCards),
                const _WishCard(
                  title: 'Камера',
                  subtitle: 'Sony A7 IV body',
                  meta: '180 000 ₽',
                ),
                const SizedBox(height: AppSpacing.lg),
                // Add wish
                const AppButton(
                  label: 'Добавить желание',
                  expand: true,
                  leading: Icon(PhosphorIconsRegular.plus),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon});
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      color: colors.surfaceMuted,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {},
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: AppSizes.iconButtonSize,
          height: AppSizes.iconButtonSize,
          child: IconTheme.merge(
            data: IconThemeData(
              color: colors.textSecondary,
              size: AppSizes.appBarIconSize,
            ),
            child: icon,
          ),
        ),
      ),
    );
  }
}

class _WishCard extends StatelessWidget {
  const _WishCard({
    required this.title,
    required this.subtitle,
    required this.meta,
    this.reserved = false,
  });

  final String title;
  final String subtitle;
  final String meta;
  final bool reserved;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final t = AppTypography.of(context);
    return AppCard(
      onTap: () {},
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.secondary,
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            alignment: Alignment.center,
            child: Icon(
              PhosphorIconsRegular.gift,
              color: colors.secondaryForeground,
              size: AppSizes.iconSize,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: t.bodyMedium),
                const SizedBox(height: 2),
                Text(subtitle, style: t.secondary),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(meta, style: t.caption.copyWith(color: colors.textPrimary)),
              if (reserved) ...[
                const SizedBox(height: 2),
                AppChip(
                  label: 'Забронировано',
                  leading: Icon(
                    Icons.check_circle,
                    color: colors.success,
                    size: 12,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
