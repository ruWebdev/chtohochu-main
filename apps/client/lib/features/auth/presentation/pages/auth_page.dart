import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_sizes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/ui/ui.dart';
import '../../../session/presentation/providers/app_session_controller.dart';
import '../../data/auth_repository.dart';
import '../providers/auth_controller.dart';

/// Длительность коротких layout-анимаций экрана.
const _kAnimDuration = Duration(milliseconds: 180);

/// Экран авторизации: вход и регистрация.
///
/// Композиция с нижним якорем: бренд-блок сверху, форма и действия
/// прижаты к низу через [Spacer]. Рост контента (ошибки, поле имени
/// в режиме регистрации) поглощается spacer'ом — CTA, разделитель и
/// OAuth-кнопки не меняют позицию. Ошибки полей живут в постоянно
/// зарезервированной строке под полем (`helperText`-слот).
class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _obscurePassword = true;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  bool _validateEmail(String email) {
    final regex = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
    return regex.hasMatch(email);
  }

  bool _validate() {
    final l10n = context.l10n;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    bool ok = true;

    if (!_validateEmail(email)) {
      _emailError = l10n.emailInvalid;
      ok = false;
    } else {
      _emailError = null;
    }

    if (password.length < 8) {
      _passwordError = l10n.passwordTooShort;
      ok = false;
    } else {
      _passwordError = null;
    }

    return ok;
  }

  Future<void> _submit() async {
    // Guard от повторной отправки: кнопка disabled во время loading,
    // но keyboard submit и программные вызовы обходят её.
    if (ref.read(authControllerProvider) is AuthFormLoading) return;
    if (!_validate()) {
      setState(() {});
      return;
    }
    final controller = ref.read(authControllerProvider.notifier);
    await controller.submit(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      name: _nameController.text.trim().isEmpty
          ? null
          : _nameController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final t = AppTypography.of(context);
    final formState = ref.watch(authControllerProvider);
    final mode = ref.read(authControllerProvider.notifier).mode;
    final isLoading = formState is AuthFormLoading;
    final l10n = context.l10n;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    // Реагируем на успешную авторизацию — навигацией управляет router redirect.
    ref.listen(authControllerProvider, (previous, next) {
      if (next is AuthFormSuccess) {
        ref
            .read(appSessionControllerProvider.notifier)
            .onAuthenticated(next.session);
      }
    });

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          // Верхний уровень — bounded Column: бренд наверху, Expanded
          // отдаёт оставшуюся высоту scroll-зоне формы. Форма внутри
          // bottom-anchored: свободное место остаётся над карточкой,
          // поэтому рост _ServerErrorSlot и карточки (поле имени)
          // не сдвигает CTA/divider/OAuth. При переполнении — scroll.
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPaddingHorizontal,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.xl),
                    _BrandHeader(collapsed: keyboardOpen),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, area) {
                          return SingleChildScrollView(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: area.maxHeight,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.end,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _ServerErrorSlot(
                                    error: formState is AuthFormIdle
                                        ? formState.error
                                        : null,
                                  ),

                                  // Форма
                                  AppCard(
                                    variant: AppCardVariant.outlined,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _ModeToggle(
                                          mode: mode,
                                          onChanged: (m) {
                                            setState(() {
                                              _emailError = null;
                                              _passwordError = null;
                                            });
                                            ref
                                                .read(
                                                  authControllerProvider
                                                      .notifier,
                                                )
                                                .setMode(m);
                                          },
                                        ),
                                        const SizedBox(height: AppSpacing.lg),
                                        AutofillGroup(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              AnimatedSize(
                                                duration: _kAnimDuration,
                                                curve: Curves.easeInOut,
                                                alignment: Alignment.topCenter,
                                                child: mode == AuthMode.register
                                                    ? AppTextField(
                                                        controller:
                                                            _nameController,
                                                        label:
                                                            l10n.authNameLabel,
                                                        hint: l10n.authNameHint,
                                                        textInputAction:
                                                            TextInputAction
                                                                .next,
                                                        semanticsLabel: l10n
                                                            .authNameSemantic,
                                                        autofillHints: const [
                                                          AutofillHints.name,
                                                        ],
                                                        helperText: ' ',
                                                        enabled: !isLoading,
                                                      )
                                                    : const SizedBox.shrink(),
                                              ),
                                              AppTextField(
                                                controller: _emailController,
                                                label: l10n.emailLabel,
                                                hint: l10n.emailHint,
                                                keyboardType:
                                                    TextInputType.emailAddress,
                                                textInputAction:
                                                    TextInputAction.next,
                                                errorText: _emailError,
                                                helperText: ' ',
                                                enabled: !isLoading,
                                                semanticsLabel:
                                                    l10n.emailSemantic,
                                                autofillHints: const [
                                                  AutofillHints.email,
                                                ],
                                                autocorrect: false,
                                                enableSuggestions: false,
                                                onChanged: (value) {
                                                  if (_emailError != null &&
                                                      _validateEmail(
                                                        value.trim(),
                                                      )) {
                                                    setState(
                                                      () => _emailError = null,
                                                    );
                                                  }
                                                },
                                              ),
                                              AppTextField(
                                                controller: _passwordController,
                                                label: l10n.passwordLabel,
                                                hint: l10n.passwordHint,
                                                obscureText: _obscurePassword,
                                                errorText: _passwordError,
                                                helperText: ' ',
                                                enabled: !isLoading,
                                                semanticsLabel:
                                                    l10n.passwordSemantic,
                                                autofillHints: [
                                                  mode == AuthMode.register
                                                      ? AutofillHints
                                                            .newPassword
                                                      : AutofillHints.password,
                                                ],
                                                autocorrect: false,
                                                enableSuggestions: false,
                                                trailing: IconButton(
                                                  icon: Icon(
                                                    _obscurePassword
                                                        ? PhosphorIconsRegular
                                                              .eye
                                                        : PhosphorIconsRegular
                                                              .eyeSlash,
                                                    size: 20,
                                                  ),
                                                  tooltip: _obscurePassword
                                                      ? l10n.showPassword
                                                      : l10n.hidePassword,
                                                  onPressed: () {
                                                    setState(
                                                      () => _obscurePassword =
                                                          !_obscurePassword,
                                                    );
                                                  },
                                                ),
                                                onSubmitted: (_) => _submit(),
                                                onChanged: (value) {
                                                  if (_passwordError != null &&
                                                      value.length >= 8) {
                                                    setState(
                                                      () =>
                                                          _passwordError = null,
                                                    );
                                                  }
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: AppSpacing.sm),
                                        AppButton(
                                          label: mode == AuthMode.login
                                              ? l10n.authLoginButton
                                              : l10n.authRegisterButton,
                                          variant: AppButtonVariant.primary,
                                          size: AppButtonSize.lg,
                                          expand: true,
                                          isLoading: isLoading,
                                          enabled: !isLoading,
                                          onPressed: _submit,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xl),

                                  // Разделитель
                                  Row(
                                    children: [
                                      const Expanded(child: Divider()),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpacing.sm,
                                        ),
                                        child: Text(
                                          l10n.orSeparator,
                                          style: t.captionSmall,
                                        ),
                                      ),
                                      const Expanded(child: Divider()),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.lg),

                                  // OAuth (пока не реализован — info feedback)
                                  _OAuthButton(
                                    label: l10n.authVkButton,
                                    assetPath: 'assets/images/vk.png',
                                    onPressed: isLoading
                                        ? null
                                        : () => ref
                                              .read(
                                                authControllerProvider.notifier,
                                              )
                                              .loginWithVk(),
                                  ),
                                  const SizedBox(
                                    height: AppSpacing.betweenFields,
                                  ),
                                  _OAuthButton(
                                    label: l10n.authYandexButton,
                                    assetPath: 'assets/images/yandex.png',
                                    onPressed: isLoading
                                        ? null
                                        : () => ref
                                              .read(
                                                authControllerProvider.notifier,
                                              )
                                              .loginWithYandex(),
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Брендовый блок: бейдж с иконкой, название приложения, статичный tagline.
///
/// При открытой клавиатуре (`collapsed`) плавно схлопывается — освобождает
/// вертикаль для формы. Одно событие → одна анимация, без каскада прыжков.
class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.collapsed});

  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final t = AppTypography.of(context);
    final l10n = context.l10n;

    return AnimatedSize(
      duration: _kAnimDuration,
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: AnimatedOpacity(
        duration: _kAnimDuration,
        opacity: collapsed ? 0 : 1,
        child: collapsed
            ? const SizedBox.shrink()
            : Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: colors.secondary,
                      borderRadius: BorderRadius.circular(AppRadii.xl),
                    ),
                    child: Icon(
                      PhosphorIconsRegular.heart,
                      size: 28,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.appName,
                    textAlign: TextAlign.center,
                    style: t.screenTitle,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    l10n.authTagline,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.secondary,
                  ),
                ],
              ),
      ),
    );
  }
}

/// Слот ошибки уровня сервера/сети между бренд-блоком и формой.
///
/// Находится в зоне, поглощаемой `Spacer`: появление блока занимает
/// свободное место, а не толкает форму вниз. При отсутствии ошибки
/// занимает нулевую высоту. `OAuthUnavailableError` показывается как
/// информационное сообщение (AppFeedbackType.info), а не как ошибка.
class _ServerErrorSlot extends ConsumerStatefulWidget {
  const _ServerErrorSlot({required this.error});

  final AuthError? error;

  @override
  ConsumerState<_ServerErrorSlot> createState() => _ServerErrorSlotState();
}

class _ServerErrorSlotState extends ConsumerState<_ServerErrorSlot> {
  /// Задержка автоматического скрытия сообщения.
  static const _dismissDelay = Duration(seconds: 5);

  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _armDismissTimer();
  }

  @override
  void didUpdateWidget(_ServerErrorSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Новое сообщение → новый отсчёт; исчезновение → отмена.
    if (widget.error != oldWidget.error) {
      _armDismissTimer();
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  void _armDismissTimer() {
    _dismissTimer?.cancel();
    _dismissTimer = widget.error == null
        ? null
        : Timer(_dismissDelay, _dismiss);
  }

  void _dismiss() {
    ref.read(authControllerProvider.notifier).clearError();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final error = widget.error;

    final isInfo = error is OAuthUnavailableError;
    final Widget? content = error == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: AppFeedback(
              type: isInfo ? AppFeedbackType.info : AppFeedbackType.error,
              compact: true,
              title: isInfo
                  ? l10n.oauthUnavailableTitle
                  : authErrorMessage(l10n, error),
            ),
          );

    // Semantics-контейнер: появление блока доступно screen reader'у
    // как отдельный узел, liveRegion анонсирует содержимое.
    return Semantics(
      container: true,
      liveRegion: true,
      child: AnimatedSize(
        duration: _kAnimDuration,
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: content ?? const SizedBox.shrink(),
      ),
    );
  }
}

/// Переключатель режима login/register.
///
/// Компактный segmented control: зона нажатия каждой вкладки — 48px
/// ([AppSpacing.minTouchTarget]), а визуальный трек и pill меньше,
/// чтобы селектор не перетягивал внимание с названия и CTA.
class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.mode, required this.onChanged});

  final AuthMode mode;
  final ValueChanged<AuthMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final l10n = context.l10n;
    return SizedBox(
      height: AppSpacing.minTouchTarget,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Визуальный трек — компактнее зоны нажатия.
          Container(
            constraints: const BoxConstraints.expand(
              height: AppSizes.buttonHeight,
            ),
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _toggleItem(
                  context,
                  label: l10n.authTabLogin,
                  selected: mode == AuthMode.login,
                  onTap: () => onChanged(AuthMode.login),
                ),
              ),
              Expanded(
                child: _toggleItem(
                  context,
                  label: l10n.authTabRegister,
                  selected: mode == AuthMode.register,
                  onTap: () => onChanged(AuthMode.register),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _toggleItem(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final colors = context.appColors;
    final t = AppTypography.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: AppSpacing.minTouchTarget,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: AppSizes.buttonHeightSm,
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
              decoration: BoxDecoration(
                color: selected ? colors.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadii.md),
                boxShadow: selected ? context.shadowSubtle : null,
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.bodyMedium.copyWith(
                  color: selected ? colors.textPrimary : colors.textMuted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Кнопка OAuth-входа с иконкой провайдера.
class _OAuthButton extends StatelessWidget {
  const _OAuthButton({
    required this.label,
    required this.assetPath,
    this.onPressed,
  });

  final String label;
  final String assetPath;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: label,
      variant: AppButtonVariant.outline,
      size: AppButtonSize.lg,
      expand: true,
      enabled: onPressed != null,
      onPressed: onPressed,
      leading: Image.asset(assetPath, width: 20, height: 20),
    );
  }
}
