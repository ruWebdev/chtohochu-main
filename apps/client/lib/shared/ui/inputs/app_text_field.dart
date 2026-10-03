import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_sizes.dart';

/// Текстовое поле приложения.
///
/// Построено поверх Material 3 `TextField`, использует `InputDecorationTheme`
/// из дизайн-системы. Добавляет семантические удобства.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.errorText,
    this.leading,
    this.trailing,
    this.obscureText = false,
    this.enabled = true,
    this.maxLines = 1,
    this.minLines,
    this.keyboardType,
    this.textInputAction,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.semanticsLabel,
    this.helperText,
    this.autofillHints,
    this.autocorrect = true,
    this.enableSuggestions = true,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? label;
  final String? hint;
  final String? errorText;
  final Widget? leading;
  final Widget? trailing;
  final bool obscureText;
  final bool enabled;
  final int? maxLines;
  final int? minLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? semanticsLabel;

  /// Текст-подсказка под полем. Занимает ту же строку, что и errorText —
  /// передача пробельного `helperText` резервирует место под ошибку и
  /// стабилизирует высоту поля.
  final String? helperText;

  /// Подсказки системного autofill (AutofillHints.*).
  final Iterable<String>? autofillHints;
  final bool autocorrect;
  final bool enableSuggestions;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final iconColor = colors.textMuted;

    Widget field = TextField(
      controller: controller,
      focusNode: focusNode,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
        errorMaxLines: 1,
        helperText: helperText,
        helperMaxLines: 1,
        prefixIcon: leading != null
            ? IconTheme.merge(
                data: IconThemeData(color: iconColor, size: AppSizes.iconSize),
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 12, end: 8),
                  child: leading,
                ),
              )
            : null,
        prefixIconConstraints: const BoxConstraints(
          minWidth: AppSizes.iconSize + 20,
        ),
        suffixIcon: trailing != null
            ? IconTheme.merge(
                data: IconThemeData(color: iconColor, size: AppSizes.iconSize),
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 8, end: 12),
                  child: trailing,
                ),
              )
            : null,
      ),
      obscureText: obscureText,
      enabled: enabled,
      maxLines: obscureText ? 1 : maxLines,
      minLines: minLines,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofocus: autofocus,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      autofillHints: autofillHints,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
      style: Theme.of(context).textTheme.bodyMedium,
    );

    // Semantics с `label` без контейнера — переопределяет имя ноды поля
    // для screen reader, не создавая отдельный семантический элемент.
    if (semanticsLabel != null) {
      field = Semantics(label: semanticsLabel, child: field);
    }
    return field;
  }
}
