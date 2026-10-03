import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/preferences_service.dart';
import '../../../session/presentation/providers/app_session_controller.dart';

/// Контроллер onboarding flow.
///
/// Управляет текущей страницей и завершением onboarding.
/// Завершение сохраняется в `SharedPreferences` и обновляет
/// [AppSessionController].
class OnboardingController extends Notifier<int> {
  @override
  int build() => 0;

  /// Установить текущую страницу (вызывается из `onPageChanged`
  /// `PageView` — и при свайпе, и при программном переходе).
  void goTo(int page) => state = page;

  /// Завершить onboarding: сохранить флаг и обновить сессию.
  Future<void> complete() async {
    await ref.read(preferencesServiceProvider).setOnboardingComplete();
    await ref
        .read(appSessionControllerProvider.notifier)
        .onOnboardingComplete();
  }

  /// Пропустить onboarding — то же, что complete.
  Future<void> skip() => complete();
}

/// Провайдер контроллера onboarding.
final onboardingControllerProvider =
    NotifierProvider<OnboardingController, int>(OnboardingController.new);
