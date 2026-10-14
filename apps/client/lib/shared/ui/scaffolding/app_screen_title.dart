import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';

/// Крупный заголовок экрана — первый блок тела страницы.
///
/// [AppShellBar] содержит только навигационные кнопки и действия;
/// заголовок и подзаголовок живут ниже, над контентом — как
/// large title в iOS-паттерне. Блок фиксированный (не скроллится)
/// и имеет собственные горизонтальные отступы
/// [AppSpacing.screenPaddingHorizontal].
///
/// Опционально принимает [leading] (например, аватар на главной)
/// и флаг [centered] для экранов с центрированной шапкой (профиль).
class AppScreenTitle extends StatelessWidget {
  const AppScreenTitle({
    super.key,
    this.title,
    this.subtitle,
    this.subtitleTrailing,
    this.leading,
    this.centered = false,
  });

  /// Заголовок экрана (стиль `screenTitle`).
  final String? title;

  /// Опциональный подзаголовок (например, количество элементов).
  final String? subtitle;

  /// Опциональный микро-виджет после текста подзаголовка
  /// (например, индикатор синхронизации). Не переносится,
  /// текст слева сжимается ellipsis'ом.
  final Widget? subtitleTrailing;

  /// Опциональный leading-виджет слева от текста (аватар).
  final Widget? leading;

  /// Центрирование заголовка и подзаголовка (например, профиль).
  final bool centered;

  @override
  Widget build(BuildContext context) {
    if (title == null && subtitle == null) return const SizedBox.shrink();

    final colors = context.appColors;
    final t = AppTypography.of(context);
    final alignment = centered
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;

    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.only(
          left: AppSpacing.screenPaddingHorizontal,
          right: AppSpacing.screenPaddingHorizontal,
          bottom: AppSpacing.xs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: alignment,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null)
                    Text(
                      title!,
                      style: t.screenTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (subtitle != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            subtitle!,
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
          ],
        ),
      ),
    );
  }
}
