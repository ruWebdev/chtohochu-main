import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../l10n/l10n.dart';
import '../buttons/app_button.dart';

/// Диалог подтверждения в стиле дизайн-системы.
Future<bool?> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmLabel,
  String? cancelLabel,
  bool destructive = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          AppButton(
            label: cancelLabel ?? context.l10n.cancel,
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.sm,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          AppButton(
            label: confirmLabel ?? context.l10n.ok,
            variant: destructive
                ? AppButtonVariant.destructive
                : AppButtonVariant.primary,
            size: AppButtonSize.sm,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      );
    },
  );
}

/// Простой диалог с одним сообщением.
Future<void> showAppInfoDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? closeLabel,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          AppButton(
            label: closeLabel ?? context.l10n.close,
            variant: AppButtonVariant.primary,
            size: AppButtonSize.sm,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
    },
  );
}

/// Bottom sheet в стиле дизайн-системы.
///
/// `builder` получает `BuildContext` и функцию для закрытия sheet.
Future<T?> showAppBottomSheet<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
  bool showDragHandle = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: showDragHandle,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              builder(context),
            ],
          ),
        ),
      );
    },
  );
}
