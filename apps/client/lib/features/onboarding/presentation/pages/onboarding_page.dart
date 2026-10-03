import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/ui/ui.dart';
import '../providers/onboarding_controller.dart';

/// Данные одного onboarding-слайда.
class _SlideData {
  const _SlideData({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

/// Слайды собираются в build — тексты локализованы через [l10n].
List<_SlideData> _slides(AppLocalizations l10n) => <_SlideData>[
  _SlideData(
    icon: PhosphorIconsRegular.heart,
    title: l10n.onboardingSlide1Title,
    description: l10n.onboardingSlide1Description,
  ),
  _SlideData(
    icon: PhosphorIconsRegular.bookmarkSimple,
    title: l10n.onboardingSlide2Title,
    description: l10n.onboardingSlide2Description,
  ),
  _SlideData(
    icon: PhosphorIconsRegular.users,
    title: l10n.onboardingSlide3Title,
    description: l10n.onboardingSlide3Description,
  ),
];

/// Экран onboarding.
///
/// Короткая история о ценности продукта (3 слайда), ведущая к регистрации.
/// Не перечисляет функции, не рассказывает про продавцов и монетизацию.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  /// Управляет видимой страницей `PageView`. Текущий индекс —
  /// единый источник правды в [onboardingControllerProvider]:
  /// обновляется через `onPageChanged` и при свайпе, и при «Далее».
  final _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Анимированный переход к следующему слайду.
  /// Индекс обновится через `onPageChanged` → `controller.goTo`.
  void _next() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final t = AppTypography.of(context);
    final currentPage = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);
    final l10n = context.l10n;
    final slides = _slides(l10n);
    final isLast = currentPage == slides.length - 1;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar: Skip
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: TextButton(
                  onPressed: controller.skip,
                  child: Text(l10n.onboardingSkip),
                ),
              ),
            ),
            // Slides
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: slides.length,
                onPageChanged: controller.goTo,
                itemBuilder: (context, index) {
                  final slide = slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconTheme.merge(
                          data: IconThemeData(color: colors.primary, size: 64),
                          child: Icon(slide.icon),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: t.sectionTitle,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          slide.description,
                          textAlign: TextAlign.center,
                          style: t.secondary,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Progress dots
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(slides.length, (i) {
                  final active = i == currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active ? colors.primary : colors.border,
                      borderRadius: BorderRadius.circular(AppRadii.full),
                    ),
                  );
                }),
              ),
            ),
            // CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPaddingHorizontal,
                0,
                AppSpacing.screenPaddingHorizontal,
                AppSpacing.lg,
              ),
              child: AppButton(
                label: isLast ? l10n.onboardingStart : l10n.onboardingNext,
                expand: true,
                trailing: isLast
                    ? null
                    : const Icon(PhosphorIconsRegular.arrowRight),
                onPressed: () {
                  if (isLast) {
                    controller.complete();
                  } else {
                    _next();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
