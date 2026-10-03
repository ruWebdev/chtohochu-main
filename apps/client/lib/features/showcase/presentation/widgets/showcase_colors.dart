import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';

/// Секция: цветовые токены.
class ShowcaseColors extends StatelessWidget {
  const ShowcaseColors({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final swatches = <_Swatch>[
      _Swatch('primary', colors.primary, colors.primaryForeground),
      _Swatch('secondary', colors.secondary, colors.secondaryForeground),
      _Swatch('background', colors.background, colors.textPrimary),
      _Swatch('surface', colors.surface, colors.textPrimary),
      _Swatch('surfaceElevated', colors.surfaceElevated, colors.textPrimary),
      _Swatch('surfaceMuted', colors.surfaceMuted, colors.textPrimary),
      _Swatch('textPrimary', colors.textPrimary, colors.surface),
      _Swatch('textSecondary', colors.textSecondary, colors.surface),
      _Swatch('textMuted', colors.textMuted, colors.surface),
      _Swatch('border', colors.border, colors.textPrimary),
      _Swatch('divider', colors.divider, colors.textPrimary),
      _Swatch('success', colors.success, Colors.white),
      _Swatch('warning', colors.warning, Colors.white),
      _Swatch('error', colors.error, Colors.white),
      _Swatch('info', colors.info, Colors.white),
    ];

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: swatches.map((s) => _SwatchTile(swatch: s)).toList(),
    );
  }
}

class _Swatch {
  const _Swatch(this.name, this.color, this.foreground);
  final String name;
  final Color color;
  final Color foreground;
}

class _SwatchTile extends StatelessWidget {
  const _SwatchTile({required this.swatch});
  final _Swatch swatch;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: 104,
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: swatch.color,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            swatch.name,
            style: TextStyle(
              color: swatch.foreground,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '#${_hex(swatch.color)}',
            style: TextStyle(
              color: swatch.foreground.withValues(alpha: 0.7),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  String _hex(Color c) {
    final value = c.toARGB32();
    final a = (value >> 24) & 0xFF;
    final r = (value >> 16) & 0xFF;
    final g = (value >> 8) & 0xFF;
    final b = value & 0xFF;
    final aHex = a.toRadixString(16).padLeft(2, '0');
    final rgb =
        '${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}';
    // Пропускаем alpha, если он FF (непрозрачный).
    return a == 0xFF ? rgb.toUpperCase() : '$aHex$rgb'.toUpperCase();
  }
}
