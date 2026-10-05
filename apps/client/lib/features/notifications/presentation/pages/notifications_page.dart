import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/ui/ui.dart';

/// Центр оповещений.
///
/// Пока страница-заготовка: механика уведомлений (backend, unread,
/// push) ещё не реализована — отображается только empty state.
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppShellBar(
        title: l10n.notificationsTitle,
        leading: AppIconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          semanticLabel: l10n.back,
          tooltip: l10n.back,
          onPressed: () => _back(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          children: [
            const SizedBox(height: AppSpacing.xxl),
            AppEmptyState(
              icon: const Icon(PhosphorIconsRegular.bell),
              title: l10n.notificationsEmptyTitle,
              description: l10n.notificationsEmptyDescription,
            ),
          ],
        ),
      ),
    );
  }
}
