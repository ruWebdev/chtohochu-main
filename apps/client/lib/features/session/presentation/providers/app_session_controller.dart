import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../../../core/database/legacy_migration.dart';
import '../../../../core/services/preferences_service.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/domain/auth_session.dart';
import '../../../auth/domain/user.dart';
import '../../../friends/presentation/providers/friends_controller.dart';
import '../../../profile/data/profile_repository.dart';
import '../../../profile/presentation/providers/profile_controller.dart';
import '../../../shopping/presentation/providers/shopping_lists_controller.dart';
import '../../../wishes/data/wish_repository.dart';
import '../../../wishes/presentation/providers/wishes_controller.dart';

/// Состояние сессии приложения — определяет стартовый маршрут.
///
/// Порядок проверки:
/// 1. onboarding не пройдён → [AppSessionNeedsOnboarding]
/// 2. не авторизован → [AppSessionNeedsAuth]
/// 3. авторизован, flow первого желания не показан → [AppSessionNeedsFirstWish]
/// 4. иначе → [AppSessionReady]
sealed class AppSessionState {
  const AppSessionState();
}

/// Загрузка — состояние ещё определяется.
class AppSessionLoading extends AppSessionState {
  const AppSessionLoading();
}

/// Нужен onboarding.
class AppSessionNeedsOnboarding extends AppSessionState {
  const AppSessionNeedsOnboarding();
}

/// Нужна авторизация.
class AppSessionNeedsAuth extends AppSessionState {
  const AppSessionNeedsAuth();
}

/// Нужен flow создания первого желания.
class AppSessionNeedsFirstWish extends AppSessionState {
  const AppSessionNeedsFirstWish();
}

/// Готов — показать home.
class AppSessionReady extends AppSessionState {
  const AppSessionReady({this.session});
  final AuthSession? session;
}

/// Контроллер сессии приложения.
///
/// При `build()` асинхронно определяет состояние из хранилищ
/// (SharedPreferences + secure storage + Drift). Cold start
/// offline работает: persisted token + user_id + профиль в
/// Drift дают сессию без сети; sync стартует в фоне.
/// Методы переходов обновляют состояние и триггерят router redirect
/// через `refreshListenable`.
class AppSessionController extends AsyncNotifier<AppSessionState> {
  // Кэшированные флаги для синхронных переходов.
  bool _onboardingDone = false;
  bool _isAuthed = false;
  bool _firstWishFlowShown = false;
  AuthSession? _session;

  @override
  Future<AppSessionState> build() async {
    final prefs = ref.read(preferencesServiceProvider);
    final wishRepo = ref.read(wishRepositoryProvider);

    _onboardingDone = prefs.isOnboardingComplete();
    _firstWishFlowShown = prefs.isFirstWishFlowShown();

    final session = await ref.read(authRepositoryProvider).currentSession();
    _isAuthed = session != null;
    _session = session;

    bool hasWishes = false;
    if (_isAuthed && session != null) {
      // Legacy SharedPreferences-кэши → Drift (one-time, до sync).
      await ref.read(legacyWishesMigrationProvider).migrate(session.user.id);
      await ref
          .read(legacyShoppingListsMigrationProvider)
          .migrate(session.user.id);
      ref.read(syncEngineProvider).attach(session.user.id);
      hasWishes = await wishRepo.hasWishes();
    }

    return _resolve(hasWishes);
  }

  AppSessionState _resolve(bool hasWishes) {
    if (!_onboardingDone) return const AppSessionNeedsOnboarding();
    if (!_isAuthed) return const AppSessionNeedsAuth();
    if (!_firstWishFlowShown && !hasWishes) {
      return const AppSessionNeedsFirstWish();
    }
    return AppSessionReady(session: _session);
  }

  /// Onboarding пройден.
  Future<void> onOnboardingComplete() async {
    _onboardingDone = true;
    state = AsyncData(_resolve(false));
  }

  /// Пользователь авторизован.
  Future<void> onAuthenticated(AuthSession session) async {
    _isAuthed = true;
    _session = session;
    await ref.read(legacyWishesMigrationProvider).migrate(session.user.id);
    await ref
        .read(legacyShoppingListsMigrationProvider)
        .migrate(session.user.id);
    ref.read(syncEngineProvider).attach(session.user.id);
    final hasWishes = await ref.read(wishRepositoryProvider).hasWishes();
    state = AsyncData(_resolve(hasWishes));
  }

  /// Желание создано — flow первого желания пройден.
  Future<void> onWishCreated() async {
    _firstWishFlowShown = true;
    await ref.read(preferencesServiceProvider).setFirstWishFlowShown();
    state = AsyncData(_resolve(true));
  }

  /// Пользователь пропустил создание первого желания.
  Future<void> skipFirstWish() async {
    _firstWishFlowShown = true;
    await ref.read(preferencesServiceProvider).setFirstWishFlowShown();
    state = AsyncData(_resolve(false));
  }

  /// Обновить профиль текущего пользователя.
  ///
  /// Local-first: пишет в Drift через [ProfileRepository] и ставит
  /// outbox-операцию — доставку делает SyncEngine. `_session`
  /// обновляется сразу: `currentUserProvider` показывает новое
  /// состояние до прихода ответа сервера.
  Future<void> updateProfile({
    required String name,
    String? username,
    String? avatarUrl,
  }) async {
    final user = await ref
        .read(profileRepositoryProvider)
        .updateProfile(name: name, username: username, avatarUrl: avatarUrl);
    final s = _session;
    if (s == null) return;
    _session = AuthSession(token: s.token, user: user);
    state = AsyncData(AppSessionReady(session: _session));
  }

  /// Есть ли несинхронизированные изменения у текущего аккаунта.
  ///
  /// Используется перед logout: pending outbox означает, что
  /// обычный выход уничтожит локальные изменения — пользователю
  /// нужно явное подтверждение destructive-действия.
  Future<int> pendingSyncCount() async {
    final userId = _session?.user.id;
    if (userId == null) return 0;
    return ref.read(appDatabaseProvider).outboxCount(userId);
  }

  /// Выход из аккаунта.
  ///
  /// Отзыв токена — best-effort (работает и offline). Затем
  /// полная очистка account-scoped данных в Drift и
  /// пользовательских кэшей — данные аккаунта не должны быть
  /// видны следующему пользователю. `onboarding_complete` и
  /// `theme_mode` — app-level, не трогаем.
  ///
  /// Вызывающий код обязан заранее проверить [pendingSyncCount]
  /// и предупредить пользователя о потере несинхронизированных
  /// изменений.
  Future<void> logout() async {
    final userId = _session?.user.id ?? _prefsCurrentUserId();
    ref.read(syncEngineProvider).detach();
    await ref.read(authRepositoryProvider).logout();
    await _clearUserData(userId);
    _isAuthed = false;
    _session = null;
    _firstWishFlowShown = false;
    state = const AsyncData(AppSessionNeedsAuth());
  }

  String? _prefsCurrentUserId() =>
      ref.read(preferencesServiceProvider).currentUserId();

  /// Очистить все пользовательские данные и состояние.
  Future<void> _clearUserData(String? userId) async {
    final prefs = ref.read(preferencesServiceProvider);
    await Future.wait([
      if (userId != null)
        ref.read(appDatabaseProvider).clearAccountData(userId),
      prefs.clearLegacyWishesCache(),
      prefs.clearShoppingListsCache(),
      prefs.clearFriendsCache(),
      prefs.clearUserProfileCache(),
      prefs.resetFirstWishFlowShown(),
    ]);
    ref
      ..invalidate(wishesControllerProvider)
      ..invalidate(shoppingListsControllerProvider)
      ..invalidate(friendsControllerProvider)
      ..invalidate(friendSearchProvider)
      ..invalidate(profileControllerProvider);
  }
}

/// Провайдер состояния сессии.
final appSessionControllerProvider =
    AsyncNotifierProvider<AppSessionController, AppSessionState>(
      AppSessionController.new,
    );

/// Текущий пользователь — для экрана профиля и других мест,
/// где нужен «я».
///
/// Source of truth — таблица `profiles` в Drift (реактивно:
/// локальные мутации и reconcile из sync видны сразу).
/// `session.user` — fallback, пока profile-stream не отдал
/// первую эмиссию (холодный старт, ещё не записанная строка).
final currentUserProvider = Provider<User?>((ref) {
  final s = ref.watch(appSessionControllerProvider).value;
  if (s is! AppSessionReady) return null;
  final sessionUser = s.session?.user;
  if (sessionUser == null) return null;
  return ref.watch(profileControllerProvider).value ?? sessionUser;
});
