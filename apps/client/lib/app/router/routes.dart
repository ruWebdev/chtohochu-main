/// Константы маршрутов приложения.
class AppRoutes {
  const AppRoutes._();

  /// Splash / загрузка — показывается пока определяется состояние сессии.
  static const String splash = '/splash';

  /// Onboarding.
  static const String onboarding = '/onboarding';

  /// Авторизация (вход / регистрация).
  static const String auth = '/auth';

  /// Создание первого желания.
  static const String firstWish = '/first-wish';

  /// Добавление нового желания.
  static const String newWish = '/wishes/new';

  /// Детали желания (`/wishes/:id`).
  static const String wishDetailsPath = '/wishes/:id';

  /// Редактирование желания (`/wishes/:id/edit`).
  static const String wishEditPath = '/wishes/:id/edit';

  /// Путь к деталям конкретного желания.
  static String wishDetails(String id) => '/wishes/$id';

  /// Путь к редактированию конкретного желания.
  static String wishEdit(String id) => '/wishes/$id/edit';

  // --- Основные разделы (внутри AppShell) ---

  /// Раздел «Что хочу» — список желаний.
  static const String home = '/home';

  /// Раздел «Покупки» — список списков.
  static const String shopping = '/shopping';

  /// Создание списка покупок.
  static const String newShoppingList = '/shopping/new';

  /// Экран конкретного списка покупок (`/shopping/:id`).
  static const String shoppingListPath = '/shopping/:id';

  /// Переименование списка покупок (`/shopping/:id/edit`).
  static const String shoppingListEditPath = '/shopping/:id/edit';

  /// Путь к конкретному списку покупок.
  static String shoppingList(String id) => '/shopping/$id';

  /// Путь к редактированию конкретного списка.
  static String shoppingListEdit(String id) => '/shopping/$id/edit';

  /// Раздел «Друзья» — список друзей.
  static const String friends = '/friends';

  /// Поиск и добавление друга.
  static const String friendAdd = '/friends/add';

  /// Профиль друга (`/friends/:id`).
  static const String friendPath = '/friends/:id';

  /// Детали желания друга (`/friends/:id/wishes/:wishId`).
  static const String friendWishPath = '/friends/:id/wishes/:wishId';

  /// Путь к профилю конкретного друга.
  static String friend(String id) => '/friends/$id';

  /// Путь к деталям желания друга.
  static String friendWish(String friendId, String wishId) =>
      '/friends/$friendId/wishes/$wishId';

  /// Раздел «Профиль» — профиль пользователя и настройки.
  static const String profile = '/profile';

  /// Редактирование профиля.
  static const String profileEdit = '/profile/edit';

  /// Центр оповещений.
  static const String notifications = '/notifications';

  /// Design System Showcase (отладочный маршрут).
  static const String showcase = '/showcase';

  /// Маршруты основной части приложения (внутри shell).
  static const List<String> shellRoutes = [home, shopping, friends, profile];
}
