import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../l10n/l10n.dart';
import '../../../app/theme/app_typography.dart';
import '../buttons/app_icon_button.dart';

/// Action для [AppShellBar].
///
/// Описывает одну контекстную action-кнопку в AppBar.
/// Каждая action — круглая [AppIconButton] с semantic label и tooltip.
class AppBarAction {
  const AppBarAction({
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.tooltip,
  });

  /// Иконка (Phosphor).
  final IconData icon;

  /// Callback при нажатии.
  final VoidCallback onPressed;

  /// Семантическая метка для accessibility.
  final String semanticLabel;

  /// Тултип при долгом нажатии (опционально).
  final String? tooltip;
}

/// Единый переиспользуемый AppBar для основных экранов приложения.
///
/// Минималистичный, компактный, визуально спокойный. Сочетается с
/// floating glass bottom bar, но не копирует его. Использует существующие
/// design tokens и [AppIconButton] для action-кнопок.
///
/// **Геометрия:** custom layout (не обёртка Material `AppBar`) для точного
/// контроля горизонтальных отступов. Левый и правый insets симметричны и
/// равны [AppSpacing.screenPaddingHorizontal] (16px).
///
/// Поддерживает:
/// * [title] — заголовок экрана (стиль `screenTitle`);
/// * [subtitle] — опциональный подзаголовок;
/// * [leading] — опциональный leading-виджет (например, back button);
/// * [actions] — контекстные action-кнопки;
/// * [overflowActions] — редко используемые действия → PopupMenu.
///
/// Не содержит бизнес-логики — получает configuration извне.
class AppShellBar extends StatelessWidget implements PreferredSizeWidget {
  const AppShellBar({
    super.key,
    this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
    this.overflowActions = const [],
  });

  /// Заголовок экрана. Если `null` — зона заголовка пустая
  /// (например, экран деталей, где заголовок в теле страницы).
  final String? title;

  /// Опциональный подзаголовок (например, количество элементов).
  final String? subtitle;

  /// Опциональный leading-виджет.
  ///
  /// На root-разделах не используется (back navigation управляется shell).
  /// На дочерних экранах — back button.
  final Widget? leading;

  /// Контекстные action-кнопки (1–3).
  ///
  /// Показываются справа. Каждая — круглая [AppIconButton].
  final List<AppBarAction> actions;

  /// Редко используемые действия → overflow menu (PopupMenuButton).
  ///
  /// Если пусто — overflow menu не показывается.
  final List<AppBarAction> overflowActions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final t = AppTypography.of(context);
    final topPadding = MediaQuery.paddingOf(context).top;

    return Material(
      color: colors.background,
      child: Padding(
        padding: EdgeInsets.only(top: topPadding),
        child: SizedBox(
          height: kToolbarHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPaddingHorizontal,
            ),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: AppSpacing.appBarLeadingGap),
                ],
                Expanded(
                  child: title == null
                      ? const SizedBox.shrink()
                      : subtitle != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title!,
                              style: t.screenTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              subtitle!,
                              style: t.secondary.copyWith(
                                color: colors.textMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        )
                      : Text(
                          title!,
                          style: t.screenTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
                ..._buildActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Строит action-виджеты с правильным spacing МЕЖДУ ними (не после последней).
  List<Widget> _buildActions() {
    final widgets = <Widget>[];
    final allActions = <AppBarAction>[...actions];

    for (var i = 0; i < allActions.length; i++) {
      if (i > 0) {
        widgets.add(const SizedBox(width: AppSpacing.appBarActionSpacing));
      }
      widgets.add(_buildActionButton(allActions[i]));
    }

    if (overflowActions.isNotEmpty) {
      if (widgets.isNotEmpty) {
        widgets.add(const SizedBox(width: AppSpacing.appBarActionSpacing));
      }
      widgets.add(_OverflowMenu(overflowActions));
    }

    return widgets;
  }

  /// Строит одну action-кнопку.
  Widget _buildActionButton(AppBarAction action) {
    return AppIconButton(
      icon: Icon(action.icon),
      onPressed: action.onPressed,
      semanticLabel: action.semanticLabel,
      tooltip: action.tooltip,
    );
  }
}

/// Overflow menu для редко используемых actions.
///
/// Использует [AppIconButton] (ghost variant) для визуальной консистентности.
/// `PopupMenuButton.padding` установлен в `EdgeInsets.zero` чтобы избежать
/// дополнительного отступа вокруг иконки.
class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu(this.actions);

  final List<AppBarAction> actions;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return PopupMenuButton<int>(
      padding: EdgeInsets.zero,
      icon: AppIconButton(
        icon: const Icon(PhosphorIconsRegular.dotsThreeVertical),
        variant: AppIconButtonVariant.ghost,
        semanticLabel: context.l10n.more,
        tooltip: context.l10n.more,
      ),
      position: PopupMenuPosition.under,
      color: colors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.border),
      ),
      itemBuilder: (context) {
        return [
          for (var i = 0; i < actions.length; i++)
            PopupMenuItem<int>(
              value: i,
              child: Row(
                children: [
                  Icon(actions[i].icon, size: 20, color: colors.textSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      actions[i].semanticLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ];
      },
      onSelected: (index) => actions[index].onPressed(),
    );
  }
}
