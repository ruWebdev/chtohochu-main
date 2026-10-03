import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/constants/app_info.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/ui/ui.dart';
import '../../../session/presentation/providers/app_session_controller.dart';
import '../../../showcase/presentation/providers/theme_controller.dart';
import '../utils/profile_formatters.dart';

/// Экран «Профиль» — кто я и настройки приложения.
///
/// Верхняя часть: аватар, имя, @username, кнопка редактирования.
/// Ниже — компактные секции: Настройки, Аккаунт, О приложении.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  Future<void> _openThemePicker(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final current = ref.read(themeModeProvider);
    final selected = await showAppBottomSheet<ThemeMode>(
      context,
      title: l10n.appearance,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final mode in ThemeMode.values)
            AppListItem(
              leading: Icon(themeModeIcon(mode)),
              title: themeModeLabel(l10n, mode),
              selected: mode == current,
              trailing: mode == current
                  ? const Icon(PhosphorIconsRegular.check)
                  : null,
              onTap: () => Navigator.of(context).pop(mode),
            ),
        ],
      ),
    );
    if (selected != null) {
      ref.read(themeModeProvider.notifier).set(selected);
    }
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final session = ref.read(appSessionControllerProvider.notifier);
    final pending = await session.pendingSyncCount();

    if (!context.mounted) return;
    final l10n = context.l10n;

    final confirmed = pending > 0
        // Есть несинхронизированные изменения — выход их удалит,
        // поэтому предупреждение строже и подтверждение явное.
        ? await showAppConfirmDialog(
            context,
            title: l10n.logoutPendingTitle,
            message: l10n.logoutPendingMessage(pending),
            confirmLabel: l10n.logoutPendingConfirm,
            destructive: true,
          )
        : await showAppConfirmDialog(
            context,
            title: l10n.logoutTitle,
            message: l10n.logoutMessage,
            confirmLabel: l10n.logout,
            destructive: true,
          );
    if (confirmed == true) {
      await session.logout();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final t = AppTypography.of(context);
    final l10n = context.l10n;
    final user = ref.watch(currentUserProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppShellBar(title: l10n.profileTitle),
      body: SafeArea(
        child: user == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPaddingHorizontal,
                  vertical: AppSpacing.sm,
                ),
                children: [
                  // --- Шапка профиля ---
                  const SizedBox(height: AppSpacing.sm),
                  Center(
                    child: AppAvatar(
                      imageUrl: user.avatarUrl,
                      initials: user.initials,
                      size: AppAvatarSize.lg,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Center(
                    child: Text(
                      user.displayName,
                      style: t.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (user.username != null && user.username!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Center(
                      child: Text(
                        '@${user.username}',
                        style: t.secondary.copyWith(color: colors.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Center(
                    child: AppButton(
                      label: l10n.profileEdit,
                      variant: AppButtonVariant.outline,
                      size: AppButtonSize.sm,
                      leading: const Icon(PhosphorIconsRegular.pencilSimple),
                      onPressed: () => context.go(AppRoutes.profileEdit),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // --- Настройки ---
                  _SectionLabel(l10n.settingsSection),
                  const SizedBox(height: AppSpacing.xs),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: AppListItem(
                      leading: const Icon(PhosphorIconsRegular.palette),
                      title: l10n.appearance,
                      subtitle: themeModeLabel(l10n, themeMode),
                      trailing: const Icon(PhosphorIconsRegular.caretRight),
                      onTap: () => _openThemePicker(context, ref),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // --- Аккаунт ---
                  _SectionLabel(l10n.accountSection),
                  const SizedBox(height: AppSpacing.xs),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: AppListItem(
                      leading: const Icon(PhosphorIconsRegular.signOut),
                      title: l10n.logout,
                      destructive: true,
                      onTap: () => _confirmLogout(context, ref),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // --- О приложении ---
                  _SectionLabel(l10n.aboutSection),
                  const SizedBox(height: AppSpacing.xs),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: AppListItem(
                      leading: const Icon(PhosphorIconsRegular.info),
                      title: AppInfo.name,
                      subtitle: l10n.versionLabel(AppInfo.version),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
      ),
    );
  }
}

/// Заголовок секции профиля.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final t = AppTypography.of(context);
    return Text(text, style: t.caption.copyWith(color: colors.textMuted));
  }
}
