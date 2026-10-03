import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../app/theme/app_spacing.dart';
import '../widgets/showcase_app_bar.dart';
import '../providers/theme_controller.dart';
import '../widgets/showcase_avatars.dart';
import '../widgets/showcase_buttons.dart';
import '../widgets/showcase_cards.dart';
import '../widgets/showcase_chips.dart';
import '../widgets/showcase_colors.dart';
import '../widgets/showcase_dialogs.dart';
import '../widgets/showcase_empty_state.dart';
import '../widgets/showcase_feedback.dart';
import '../widgets/showcase_icon_buttons.dart';
import '../widgets/showcase_lists.dart';
import '../widgets/showcase_product_example.dart';
import '../widgets/showcase_section.dart';
import '../widgets/showcase_text_fields.dart';
import '../widgets/showcase_typography.dart';

/// Главный экран Design System Showcase.
///
/// Открывается при запуске приложения вместо продуктовых экранов.
/// Демонстрирует все токены и компоненты дизайн-системы, а также
/// пример реального экрана «ЧтоХочу».
class ShowcasePage extends ConsumerStatefulWidget {
  const ShowcasePage({super.key});

  @override
  ConsumerState<ShowcasePage> createState() => _ShowcasePageState();
}

class _ShowcasePageState extends ConsumerState<ShowcasePage> {
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final typography = AppTypography.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ShowcaseAppBar(
          title: 'Design System',
          onToggleTheme: ref.read(themeModeProvider.notifier).toggle,
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPaddingHorizontal,
            vertical: AppSpacing.md,
          ),
          children: [
            Text('ЧтоХочу · v0.1', style: typography.captionSmall),
            const SizedBox(height: AppSpacing.xxs),
            Text('Визуальный язык продукта', style: typography.screenTitle),
            const SizedBox(height: AppSpacing.sectionGap),
            const ShowcaseSection(
              title: 'Цвета',
              description: 'Брендовый акцент, тёплые поверхности, семантика.',
              child: ShowcaseColors(),
            ),
            const ShowcaseSection(
              title: 'Типографика',
              description: 'Open Sans, компактная шкала, semantic-токены.',
              child: ShowcaseTypography(),
            ),
            const ShowcaseSection(
              title: 'Кнопки',
              description: 'Primary, secondary, outline, ghost, destructive.',
              child: ShowcaseButtons(),
            ),
            const ShowcaseSection(
              title: 'Круглые icon buttons',
              description: 'AppBar actions, компактные, мягкий фон.',
              child: ShowcaseIconButtons(),
            ),
            const ShowcaseSection(
              title: 'Поля ввода',
              description: 'Обычное, focused, error, disabled, icon, password.',
              child: ShowcaseTextFields(),
            ),
            const ShowcaseSection(
              title: 'Карточки',
              description: 'Outlined, elevated, muted, с action.',
              child: ShowcaseCards(),
            ),
            const ShowcaseSection(
              title: 'Chips',
              description: 'Обычный, selected, disabled, status.',
              child: ShowcaseChips(),
            ),
            const ShowcaseSection(
              title: 'Аватары',
              description: 'S / M / L, placeholder, индикатор статуса.',
              child: ShowcaseAvatars(),
            ),
            const ShowcaseSection(
              title: 'Списки',
              description: 'Иконка, аватар, trailing, selected, disabled.',
              child: ShowcaseLists(),
            ),
            const ShowcaseSection(
              title: 'Feedback',
              description: 'Success, warning, error, info — мягкие блоки.',
              child: ShowcaseFeedback(),
            ),
            const ShowcaseSection(
              title: 'Empty state',
              description: 'Иконка → заголовок → описание → action.',
              child: ShowcaseEmptyState(),
            ),
            const ShowcaseSection(
              title: 'Dialog / Bottom Sheet',
              description: 'Подтверждение, информация, bottom sheet.',
              child: ShowcaseDialogs(),
            ),
            const ShowcaseSection(
              title: 'Пример экрана ЧтоХочу',
              description: 'Как дизайн-система работает в реальном продукте.',
              child: ShowcaseProductExample(),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Center(
              child: Text(
                'Phosphor Icons · Open Sans · Material 3',
                style: typography.captionSmall,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}
