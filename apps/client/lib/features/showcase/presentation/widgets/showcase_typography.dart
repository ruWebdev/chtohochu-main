import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';

/// Секция: типографика.
class ShowcaseTypography extends StatelessWidget {
  const ShowcaseTypography({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppTypography.of(context);
    final colors = context.appColors;

    final samples = <_Sample>[
      _Sample('display · 28/36/600', t.display, 'ЧтоХочу'),
      _Sample('screenTitle · 24/32/600', t.screenTitle, 'Мои желания'),
      _Sample('sectionTitle · 22/30/600', t.sectionTitle, 'На день рождения'),
      _Sample('title · 18/24/600', t.title, 'Беспроводные наушники'),
      _Sample(
        'bodyLarge · 16/24/400',
        t.bodyLarge,
        'Собери всё, чего ты хочешь, в одном месте.',
      ),
      _Sample(
        'body · 15/22/400',
        t.body,
        'Поделись желаниями с близкими — им больше не придётся гадать.',
      ),
      _Sample('bodyMedium · 15/22/500', t.bodyMedium, 'Добавить желание'),
      _Sample('secondary · 14/20/400', t.secondary, 'Обновлено 5 минут назад'),
      _Sample('caption · 13/18/500', t.caption, '12 желаний · 3 списка'),
      _Sample(
        'captionSmall · 12/18/400',
        t.captionSmall,
        'Phosphor · Open Sans',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < samples.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          Text(
            samples[i].label,
            style: t.captionSmall.copyWith(color: colors.textMuted),
          ),
          Text(samples[i].text, style: samples[i].style),
        ],
      ],
    );
  }
}

class _Sample {
  const _Sample(this.label, this.style, this.text);
  final String label;
  final TextStyle style;
  final String text;
}
