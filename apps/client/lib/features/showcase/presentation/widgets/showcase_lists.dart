import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/ui/ui.dart';
import 'showcase_section.dart';

/// Секция: списки.
class ShowcaseLists extends StatelessWidget {
  const ShowcaseLists({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ShowcaseSubLabel('Простой list item'),
        const AppListItem(title: 'Беспроводные наушники'),
        const ShowcaseSubLabel('С leading иконкой'),
        const AppListItem(
          title: 'Электроника',
          leading: Icon(PhosphorIconsRegular.heart),
        ),
        const ShowcaseSubLabel('С аватаром'),
        const AppListItem(
          title: 'Анна',
          subtitle: '5 желаний',
          leading: AppAvatar(initials: 'АН', size: AppAvatarSize.sm),
        ),
        const ShowcaseSubLabel('С trailing action'),
        const AppListItem(
          title: 'Книга по фотографии',
          subtitle: '2 490 ₽',
          trailing: Icon(PhosphorIconsRegular.caretRight),
        ),
        const ShowcaseSubLabel('Selected'),
        const AppListItem(
          title: 'Наушники Sony WH-1000XM6',
          selected: true,
          trailing: Icon(PhosphorIconsRegular.check),
        ),
        const ShowcaseSubLabel('Disabled'),
        const AppListItem(
          title: 'Недоступный пункт',
          enabled: false,
          trailing: Icon(PhosphorIconsRegular.caretRight),
        ),
        const ShowcaseSubLabel('С разделителем'),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            children: const [
              AppListItem(title: 'Наушники', subtitle: 'Sony WH-1000XM6'),
              AppListDivider(indent: 16),
              AppListItem(title: 'Книга', subtitle: 'По фотографии'),
              AppListDivider(indent: 16),
              AppListItem(title: 'Камера', subtitle: 'Sony A7 IV'),
            ],
          ),
        ),
      ],
    );
  }
}
