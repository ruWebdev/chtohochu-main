import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_sizes.dart';

/// Центральная кнопка «добавить» нижней навигации.
///
/// Фирменный элемент приложения: кнопка сидит в мягком круглом
/// «гнезде» (secondary-поверхность + тонкий primary-ободок) и
/// визуально врезана внутрь бара — ничего не выступает за его
/// границы.
///
/// Сама кнопка собрана из слоёв: диагональный градиент primary
/// (свет сверху-слева), внутренний верхний блик, тонкий светлый
/// контур, цветная тень парения + контактная тень. При нажатии —
/// короткий scale и ослабление тени, без постоянных анимаций.
class AppAddActionButton extends StatefulWidget {
  const AppAddActionButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    this.tooltip,
    this.color,
    this.onPressed,
  });

  /// Иконка действия.
  final IconData icon;

  /// Контекстная семантическая метка («Добавить желание» и т.п.).
  final String semanticLabel;

  /// Тултип при долгом нажатии.
  final String? tooltip;

  /// Акцентный цвет кнопки (база градиента и свечения).
  /// `null` — брендовый `primary` темы.
  final Color? color;

  /// Callback при нажатии. `null` — кнопка визуально неактивна
  /// (приглушённый цвет, без акцентного свечения) и не реагирует
  /// на нажатия.
  final VoidCallback? onPressed;

  @override
  State<AppAddActionButton> createState() => _AppAddActionButtonState();
}

class _AppAddActionButtonState extends State<AppAddActionButton>
    with SingleTickerProviderStateMixin {
  /// Масштаб кнопки в нажатом состоянии.
  static const double _pressedScale = 0.92;

  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 110),
    reverseDuration: const Duration(milliseconds: 220),
  );

  /// 0 — покой, 1 — полностью нажата.
  late final Animation<double> _t = CurvedAnimation(
    parent: _press,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeOutBack,
  );

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.brightnessOf(context) == Brightness.dark;
    final isEnabled = widget.onPressed != null;

    // Целевые цвета: акцент раздела или приглушённое disabled-состояние.
    final targetAccent = isEnabled
        ? (widget.color ?? colors.primary)
        : colors.surfaceMuted;
    final targetForeground = isEnabled
        ? colors.primaryForeground
        : colors.textMuted;

    final button = GestureDetector(
      onTap: widget.onPressed,
      onTapDown: isEnabled ? (_) => _press.forward() : null,
      onTapUp: isEnabled ? (_) => _press.reverse() : null,
      onTapCancel: isEnabled ? () => _press.reverse() : null,
      child: AnimatedBuilder(
        animation: _t,
        builder: (context, child) {
          final t = _t.value;
          // Плавный переход акцента при смене раздела.
          return TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: targetAccent),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            builder: (context, accent, _) => TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: targetForeground),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              builder: (context, foreground, _) => Transform.scale(
                scale: 1 - (1 - _pressedScale) * t,
                child: Container(
                  width: AppSizes.addActionButtonSize,
                  height: AppSizes.addActionButtonSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      // Цветная тень — «парение» кнопки внутри гнезда.
                      BoxShadow(
                        color: accent!.withValues(
                          alpha: isEnabled
                              ? (isDark ? 0.45 : 0.35) - 0.15 * t
                              : (isDark ? 0.15 : 0.10),
                        ),
                        blurRadius: 16 - 8 * t,
                        offset: Offset(0, 7 - 4 * t),
                        spreadRadius: -5,
                      ),
                      // Контактная тень — прижимает кнопку к гнезду.
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.30 : 0.10,
                        ),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.lerp(accent, Colors.white, isDark ? 0.22 : 0.16)!,
                        Color.lerp(accent, Colors.black, isDark ? 0.06 : 0.12)!,
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(
                        alpha: isDark ? 0.14 : 0.28,
                      ),
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Внутренний верхний блик — глянцевая грань.
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(
                                  alpha:
                                      (isDark ? 0.18 : 0.24) *
                                      (1 - t) *
                                      (isEnabled ? 1.0 : 0.4),
                                ),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.55],
                            ),
                          ),
                        ),
                      ),
                      Icon(
                        widget.icon,
                        size: AppSizes.iconSizeLg,
                        color: foreground,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    // «Гнездо»: мягкий вторичный слот, визуально врезает
    // кнопку в поверхность бара.
    final composite = SizedBox(
      width: AppSizes.addActionSocketSize,
      height: AppSizes.addActionSocketSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: AppSizes.addActionSocketSize,
            height: AppSizes.addActionSocketSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.secondary.withValues(alpha: isDark ? 0.85 : 0.9),
              border: Border.all(
                color: colors.primary.withValues(alpha: isDark ? 0.25 : 0.15),
              ),
            ),
          ),
          button,
        ],
      ),
    );

    final labeled = Semantics(
      button: true,
      enabled: isEnabled,
      label: widget.semanticLabel,
      child: composite,
    );
    return Tooltip(
      message: widget.tooltip ?? widget.semanticLabel,
      child: labeled,
    );
  }
}
