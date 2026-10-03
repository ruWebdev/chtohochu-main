import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/ui/ui.dart';
import '../../../session/presentation/providers/app_session_controller.dart';
import '../../data/profile_repository.dart';

/// Mock-варианты аватара (вместо реального upload — backend ещё нет).
const _mockAvatars = [
  'https://picsum.photos/seed/avatar-1/200/200',
  'https://picsum.photos/seed/avatar-2/200/200',
  'https://picsum.photos/seed/avatar-3/200/200',
];

/// Экран редактирования профиля.
///
/// Поля: имя, username, аватар (mock-выбор). Сохранение пишет в
/// единый state текущего пользователя через сессию.
class ProfileEditPage extends ConsumerStatefulWidget {
  const ProfileEditPage({super.key});

  @override
  ConsumerState<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends ConsumerState<ProfileEditPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  String? _avatarUrl;
  String? _nameError;
  String? _usernameError;
  bool _saving = false;

  static final _usernameRegex = RegExp('^[a-z0-9_.]{3,20}\$');

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _nameController = TextEditingController(text: user?.name ?? '');
    _usernameController = TextEditingController(text: user?.username ?? '');
    _avatarUrl = user?.avatarUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.profile);
  }

  bool _validate() {
    final l10n = context.l10n;
    final name = _nameController.text.trim();
    final username = _normalizedUsername();
    bool ok = true;
    _nameError = null;
    _usernameError = null;

    if (name.isEmpty) {
      _nameError = l10n.nameRequired;
      ok = false;
    }
    // Пустой username допустим — поле опционально.
    if (username != null && !_usernameRegex.hasMatch(username)) {
      _usernameError = l10n.usernameInvalid;
      ok = false;
    }
    return ok;
  }

  /// Нормализовать username: trim, без `@`, lowercase.
  /// `null`, если поле пустое.
  String? _normalizedUsername() {
    var v = _usernameController.text.trim();
    if (v.startsWith('@')) v = v.substring(1);
    v = v.toLowerCase();
    return v.isEmpty ? null : v;
  }

  Future<void> _pickAvatar() async {
    final l10n = context.l10n;
    final url = await showAppBottomSheet<String>(
      context,
      title: l10n.photoSheetTitle,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _mockAvatars.length; i++)
            AppListItem(
              leading: AppAvatar(imageUrl: _mockAvatars[i]),
              title: l10n.avatarOption(i + 1),
              onTap: () => Navigator.of(context).pop(_mockAvatars[i]),
            ),
          if (_avatarUrl != null)
            AppListItem(
              leading: const Icon(PhosphorIconsRegular.trash),
              title: l10n.photoRemove,
              destructive: true,
              onTap: () => Navigator.of(context).pop(''),
            ),
        ],
      ),
    );
    if (url == null || !mounted) return;
    setState(() => _avatarUrl = url.isEmpty ? null : url);
  }

  Future<void> _save() async {
    if (!_validate()) {
      setState(() {});
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(appSessionControllerProvider.notifier)
          .updateProfile(
            name: _nameController.text.trim(),
            username: _normalizedUsername(),
            avatarUrl: _avatarUrl,
          );
      if (!mounted) return;
      context.go(AppRoutes.profile);
    } on ProfileError catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(profileErrorMessage(context.l10n, e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final t = AppTypography.of(context);
    final l10n = context.l10n;
    final user = ref.watch(currentUserProvider);

    return PopScope(
      // Страница открыта через `go()` — системный Back ведёт к профилю,
      // а не закрывает приложение.
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _back();
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppShellBar(
          leading: AppIconButton(
            icon: const Icon(PhosphorIconsRegular.arrowLeft),
            variant: AppIconButtonVariant.ghost,
            semanticLabel: l10n.back,
            tooltip: l10n.back,
            onPressed: _back,
          ),
          title: l10n.profileEdit,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPaddingHorizontal,
              vertical: AppSpacing.sm,
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              // --- Аватар ---
              Center(
                child: AppAvatar(
                  imageUrl: _avatarUrl,
                  initials: user?.initials,
                  size: AppAvatarSize.lg,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Center(
                child: AppButton(
                  label: l10n.photoChange,
                  variant: AppButtonVariant.ghost,
                  size: AppButtonSize.sm,
                  onPressed: _saving ? null : _pickAvatar,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // --- Имя ---
              AppTextField(
                controller: _nameController,
                label: l10n.nameLabel,
                hint: l10n.nameHintProfile,
                errorText: _nameError,
                enabled: !_saving,
                textInputAction: TextInputAction.next,
                onChanged: (_) {
                  if (_nameError != null) {
                    setState(() => _nameError = null);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.betweenFields),

              // --- Username ---
              AppTextField(
                controller: _usernameController,
                label: l10n.usernameLabel,
                hint: l10n.usernameHint,
                leading: const Text('@'),
                errorText: _usernameError,
                enabled: !_saving,
                textInputAction: TextInputAction.done,
                onChanged: (_) {
                  if (_usernameError != null) {
                    setState(() => _usernameError = null);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                l10n.usernameHelp,
                style: t.captionSmall.copyWith(color: colors.textMuted),
              ),
              const SizedBox(height: AppSpacing.xl),

              // --- Сохранить ---
              AppButton(
                label: l10n.save,
                expand: true,
                isLoading: _saving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
