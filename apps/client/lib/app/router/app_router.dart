import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/auth_page.dart';
import '../../features/friends/presentation/pages/friend_profile_page.dart';
import '../../features/friends/presentation/pages/friend_search_page.dart';
import '../../features/friends/presentation/pages/friend_wish_details_page.dart';
import '../../features/friends/presentation/pages/friends_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_page.dart';
import '../../features/profile/presentation/pages/profile_edit_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/session/presentation/providers/app_session_controller.dart';
import '../../features/shopping/presentation/pages/shopping_list_edit_page.dart';
import '../../features/shopping/presentation/pages/shopping_list_form_page.dart';
import '../../features/shopping/presentation/pages/shopping_list_page.dart';
import '../../features/shopping/presentation/pages/shopping_page.dart';
import '../../features/showcase/presentation/pages/showcase_page.dart';
import '../../features/wishes/presentation/pages/home_page.dart';
import '../../features/wishes/presentation/pages/wish_details_page.dart';
import '../../features/wishes/presentation/pages/wish_edit_page.dart';
import '../../features/wishes/presentation/pages/wish_form_page.dart';
import 'app_shell.dart';
import 'routes.dart';
import 'splash_page.dart';

/// `ChangeNotifier`-мост между Riverpod и `GoRouter.refreshListenable`.
class _RouterRefreshNotifier extends ChangeNotifier {
  /// Оповестить слушателей (GoRouter) об изменении состояния.
  void notify() => notifyListeners();
}

/// Конфигурация GoRouter.
///
/// Redirect-логика определяет стартовый маршрут на основе
/// [AppSessionState]. Пока состояние загружается — показывает [SplashPage],
/// чтобы избежать flash неправильного экрана.
///
/// Основные разделы (home, shopping, friends, profile) обёрнуты в
/// [ShellRoute] с [AppShell] — floating bottom navigation bar.
final goRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier();
  ref.listen<dynamic>(
    appSessionControllerProvider,
    (_, _) => refreshNotifier.notify(),
  );
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final session = ref.read(appSessionControllerProvider);
      final loc = state.matchedLocation;

      // Пока состояние загружается — держим splash.
      if (session.isLoading || session.isRefreshing) {
        return loc == AppRoutes.splash ? null : AppRoutes.splash;
      }

      final s = session.value;
      if (s == null) {
        return loc == AppRoutes.splash ? null : AppRoutes.splash;
      }

      return switch (s) {
        AppSessionLoading() =>
          loc == AppRoutes.splash ? null : AppRoutes.splash,
        AppSessionNeedsOnboarding() =>
          loc == AppRoutes.onboarding ? null : AppRoutes.onboarding,
        AppSessionNeedsAuth() => loc == AppRoutes.auth ? null : AppRoutes.auth,
        AppSessionNeedsFirstWish() =>
          loc == AppRoutes.firstWish ? null : AppRoutes.firstWish,
        AppSessionReady() => _redirectWhenReady(loc),
      };
    },
    routes: <RouteBase>[
      // --- Неавторизованная часть ---
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        name: 'onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        path: AppRoutes.auth,
        name: 'auth',
        builder: (context, state) => const AuthPage(),
      ),
      GoRoute(
        path: AppRoutes.firstWish,
        name: 'firstWish',
        builder: (context, state) => const WishFormPage(isFirstWish: true),
      ),

      // --- Авторизованная часть: желания (без shell) ---
      GoRoute(
        path: AppRoutes.newWish,
        name: 'newWish',
        builder: (context, state) => const WishFormPage(),
      ),
      GoRoute(
        path: AppRoutes.wishDetailsPath,
        name: 'wishDetails',
        builder: (context, state) =>
            WishDetailsPage(wishId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.wishEditPath,
        name: 'wishEdit',
        builder: (context, state) =>
            WishEditPage(wishId: state.pathParameters['id']!),
      ),

      // --- Авторизованная часть: покупки (без shell) ---
      GoRoute(
        path: AppRoutes.newShoppingList,
        name: 'newShoppingList',
        builder: (context, state) => const ShoppingListFormPage(),
      ),
      GoRoute(
        path: AppRoutes.shoppingListPath,
        name: 'shoppingList',
        builder: (context, state) =>
            ShoppingListPage(listId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.shoppingListEditPath,
        name: 'shoppingListEdit',
        builder: (context, state) =>
            ShoppingListEditPage(listId: state.pathParameters['id']!),
      ),

      // --- Авторизованная часть: друзья (без shell) ---
      GoRoute(
        path: AppRoutes.friendAdd,
        name: 'friendAdd',
        builder: (context, state) => const FriendSearchPage(),
      ),
      GoRoute(
        path: AppRoutes.friendWishPath,
        name: 'friendWish',
        builder: (context, state) => FriendWishDetailsPage(
          friendId: state.pathParameters['id']!,
          wishId: state.pathParameters['wishId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.friendPath,
        name: 'friend',
        builder: (context, state) =>
            FriendProfilePage(friendId: state.pathParameters['id']!),
      ),

      // --- Авторизованная часть: профиль (без shell) ---
      GoRoute(
        path: AppRoutes.profileEdit,
        name: 'profileEdit',
        builder: (context, state) => const ProfileEditPage(),
      ),

      // --- Авторизованная часть: основные разделы (внутри shell) ---
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            name: 'home',
            builder: (context, state) => const HomePage(),
          ),
          GoRoute(
            path: AppRoutes.shopping,
            name: 'shopping',
            builder: (context, state) => const ShoppingPage(),
          ),
          GoRoute(
            path: AppRoutes.friends,
            name: 'friends',
            builder: (context, state) => const FriendsPage(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            name: 'profile',
            builder: (context, state) => const ProfilePage(),
          ),
        ],
      ),

      // --- Отладочный маршрут ---
      GoRoute(
        path: AppRoutes.showcase,
        name: 'showcase',
        builder: (context, state) => const ShowcasePage(),
      ),
    ],
  );
});

/// Когда сессия готова, разрешаем shell-маршруты и маршруты желаний
/// (`/wishes/*`), покупок (`/shopping/*`), друзей (`/friends/*`)
/// и профиля (`/profile/*`), и showcase.
/// Остальные маршруты редиректим на home.
String? _redirectWhenReady(String loc) {
  const allowed = [
    AppRoutes.home,
    AppRoutes.shopping,
    AppRoutes.friends,
    AppRoutes.profile,
    AppRoutes.showcase,
  ];
  if (allowed.contains(loc)) return null;
  if (loc.startsWith('/wishes/')) return null;
  if (loc.startsWith('/shopping/')) return null;
  if (loc.startsWith('/friends/')) return null;
  if (loc.startsWith('/profile/')) return null;
  return AppRoutes.home;
}
