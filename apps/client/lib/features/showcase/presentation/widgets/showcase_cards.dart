import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../shared/ui/ui.dart';
import 'showcase_section.dart';

/// Секция: карточки.
class ShowcaseCards extends StatelessWidget {
  const ShowcaseCards({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ShowcaseSubLabel('Outlined (по умолчанию)'),
        const AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Беспроводные наушники',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 2),
              Text(
                'Sony WH-1000XM6',
                style: TextStyle(fontSize: 14, color: Color(0xFF5C544B)),
              ),
            ],
          ),
        ),
        const ShowcaseSubLabel('Elevated (с тенью)'),
        AppCard(
          variant: AppCardVariant.elevated,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(PhosphorIconsRegular.gift, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Подарок',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              const Text(
                'Книга по фотографии',
                style: TextStyle(fontSize: 14, color: Color(0xFF5C544B)),
              ),
            ],
          ),
        ),
        const ShowcaseSubLabel('Muted'),
        const AppCard(
          variant: AppCardVariant.muted,
          child: Text(
            'Приглушённая карточка — для подсказок и вторичной информации.',
            style: TextStyle(fontSize: 14),
          ),
        ),
        const ShowcaseSubLabel('С action (tap)'),
        AppCard(
          onTap: () {},
          child: Row(
            children: const [
              Icon(PhosphorIconsRegular.heart, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Добавить в избранное',
                  style: TextStyle(fontSize: 15),
                ),
              ),
              Icon(PhosphorIconsRegular.caretRight, size: 18),
            ],
          ),
        ),
      ],
    );
  }
}
