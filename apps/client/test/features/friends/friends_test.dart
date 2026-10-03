import 'package:chtohochu/core/database/database_provider.dart';
import 'package:chtohochu/core/services/preferences_service.dart';
import 'package:chtohochu/features/friends/data/friends_repository.dart';
import 'package:chtohochu/features/friends/domain/friend.dart';
import 'package:chtohochu/features/friends/presentation/pages/friend_profile_page.dart';
import 'package:chtohochu/features/friends/presentation/pages/friend_search_page.dart';
import 'package:chtohochu/features/friends/presentation/pages/friend_wish_details_page.dart';
import 'package:chtohochu/features/friends/presentation/pages/friends_page.dart';
import 'package:chtohochu/shared/ui/buttons/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/test_app.dart';

const _me = 'test-user';

Map<String, Object> _basePrefs() => {
  'onboarding_complete': true,
  'first_wish_flow_shown': true,
};

/// «Серверная» фабрика: пользователи + дружбы + желания друзей —
/// как в реальном backend. Sync pull импортирует их в Drift,
/// UI читает только локальную БД.
FakeApiAdapter _apiWithFriends(List<String> friendIds) {
  final api = FakeApiAdapter(autoUserId: _me);
  api.seedUser('u1', name: 'Анна Соколова', username: 'anna.s');
  api.seedUser('u2', name: 'Максим Орлов', username: 'max_orlov');
  api.seedUser('u3', name: 'Елена Ким', username: 'elena.k');
  api.seedUser('u4', name: 'Дмитрий Волков', username: 'dima.v');
  api.seedUser('u5', name: 'Ольга Смирнова', username: 'olga_sm');
  for (final id in friendIds) {
    api.seedFriendship(_me, id);
  }
  api.seedWish('u1', {
    'id': 'u1w1',
    'title': 'Наушники Sony WH-1000XM6',
    'description': 'Чёрные, беспроводные. Старая модель совсем развалилась.',
    'price': 34990,
    'link': 'https://example.com/sony-xm6',
    'image_url': 'https://picsum.photos/seed/xm6/600/400',
    'created_at': '2025-09-01T00:00:00.000Z',
    'updated_at': '2025-09-01T00:00:00.000Z',
  });
  api.seedWish('u1', {
    'id': 'u1w2',
    'title': 'Книга «Мастер и Маргарита»',
    'description': 'В хорошем издании с иллюстрациями',
    'price': 1500,
    'link': null,
    'image_url': null,
    'created_at': '2025-08-20T00:00:00.000Z',
    'updated_at': '2025-08-20T00:00:00.000Z',
  });
  api.seedWish('u2', {
    'id': 'u2w1',
    'title': 'Набор инструментов',
    'description': 'Для дома, хром-ванадиевые',
    'price': 5990,
    'link': null,
    'image_url': null,
    'created_at': '2025-09-05T00:00:00.000Z',
    'updated_at': '2025-09-05T00:00:00.000Z',
  });
  api.seedWish('u4', {
    'id': 'u4w1',
    'title': 'Механическая клавиатура',
    'description': null,
    'price': 8900,
    'link': 'https://example.com/keyboard',
    'image_url': null,
    'created_at': '2025-09-10T00:00:00.000Z',
    'updated_at': '2025-09-10T00:00:00.000Z',
  });
  api.seedWish('u4', {
    'id': 'u4w2',
    'title': 'Термокружка 500 мл',
    'description': null,
    'price': null,
    'link': null,
    'image_url': null,
    'created_at': '2025-08-28T00:00:00.000Z',
    'updated_at': '2025-08-28T00:00:00.000Z',
  });
  api.seedWish('u4', {
    'id': 'u4w3',
    'title': 'Поход в горы на выходные',
    'description': 'Давно хотел съездить в Архыз',
    'price': null,
    'link': null,
    'image_url': null,
    'created_at': '2025-08-15T00:00:00.000Z',
    'updated_at': '2025-08-15T00:00:00.000Z',
  });
  api.seedWish('u5', {
    'id': 'u5w1',
    'title': 'Абонемент в бассейн',
    'description': null,
    'price': 4000,
    'link': null,
    'image_url': null,
    'created_at': '2025-09-12T00:00:00.000Z',
    'updated_at': '2025-09-12T00:00:00.000Z',
  });
  return api;
}

Future<void> _openFriends(WidgetTester tester) async {
  await tester.tap(find.text('Друзья'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Empty friends section shows empty state with CTA', (
    tester,
  ) async {
    final widget = await createTestApp(
      preferences: _basePrefs(),
      secureStorage: {'access_token': 'mock_token'},
      api: FakeApiAdapter(autoUserId: _me),
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await _openFriends(tester);

    expect(find.byType(FriendsPage), findsOneWidget);
    expect(find.text('Пока нет друзей'), findsOneWidget);
    expect(find.textContaining('Добавьте близких'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Добавить друга'), findsOneWidget);
  });

  testWidgets('One friend renders card with wish count', (tester) async {
    final api = _apiWithFriends(['u2']);
    final widget = await createTestApp(
      preferences: _basePrefs(),
      secureStorage: {'access_token': 'mock_token'},
      api: api,
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await _openFriends(tester);

    expect(find.text('Максим Орлов'), findsOneWidget);
    expect(find.text('1 друг'), findsOneWidget);
  });

  testWidgets('Several friends render with names and subtitle', (tester) async {
    final api = _apiWithFriends(['u1', 'u2', 'u4']);
    final widget = await createTestApp(
      preferences: _basePrefs(),
      secureStorage: {'access_token': 'mock_token'},
      api: api,
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await _openFriends(tester);

    expect(find.text('Анна Соколова'), findsOneWidget);
    expect(find.text('Максим Орлов'), findsOneWidget);
    expect(find.text('Дмитрий Волков'), findsOneWidget);
    expect(find.textContaining('anna.s'), findsOneWidget);
    expect(find.text('3 друга'), findsOneWidget);
  });

  testWidgets('Opening a friend shows profile with cached wishes', (
    tester,
  ) async {
    final api = _apiWithFriends(['u1', 'u4']);
    final widget = await createTestApp(
      preferences: _basePrefs(),
      secureStorage: {'access_token': 'mock_token'},
      api: api,
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await _openFriends(tester);

    await tester.tap(find.text('Анна Соколова'));
    await tester.pumpAndSettle();

    expect(find.byType(FriendProfilePage), findsOneWidget);
    expect(find.textContaining('@anna.s'), findsOneWidget);
    // Желания подъезжают из friend_wishes после refresh.
    expect(find.textContaining('Наушники Sony'), findsOneWidget);
    expect(find.textContaining('Мастер и Маргарита'), findsOneWidget);
    // Желание другого друга не показывается.
    expect(find.textContaining('Механическая клавиатура'), findsNothing);
  });

  testWidgets('Friend without wishes shows friendly empty state', (
    tester,
  ) async {
    final api = _apiWithFriends(['u3']);
    final widget = await createTestApp(
      preferences: _basePrefs(),
      secureStorage: {'access_token': 'mock_token'},
      api: api,
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await _openFriends(tester);

    await tester.tap(find.text('Елена Ким'));
    await tester.pumpAndSettle();

    expect(find.byType(FriendProfilePage), findsOneWidget);
    expect(find.text('Пока нет желаний'), findsOneWidget);
    // Нет кнопки «Добавить желание» — чужой профиль.
    expect(find.widgetWithText(AppButton, 'Добавить'), findsNothing);
  });

  testWidgets('Search shows initial hint, results and add state', (
    tester,
  ) async {
    final api = _apiWithFriends(['u1']);
    final widget = await createTestApp(
      preferences: _basePrefs(),
      secureStorage: {'access_token': 'mock_token'},
      api: api,
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await _openFriends(tester);

    // + в AppBar → экран поиска.
    await tester.tap(find.byTooltip('Добавить друга'));
    await tester.pumpAndSettle();

    expect(find.byType(FriendSearchPage), findsOneWidget);
    // Initial — подсказка до ввода.
    expect(find.text('Найдите друга'), findsOneWidget);

    // Results — network-only поиск по fake API.
    await tester.enterText(find.byType(TextField), 'ольга');
    await tester.pump(const Duration(milliseconds: 400)); // debounce
    await tester.pumpAndSettle();
    expect(find.text('Ольга Смирнова'), findsOneWidget);
    expect(find.text('@olga_sm'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Добавить'), findsOneWidget);

    // Added — локально мгновенно, POST уходит из outbox.
    await tester.tap(find.widgetWithText(AppButton, 'Добавить'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('Добавлен'), findsOneWidget);
    expect(api.friendsOf(_me), contains('u5'));

    // Назад → в списке появилась Ольга.
    await tester.tap(find.byTooltip('Назад'));
    await tester.pumpAndSettle();
    expect(find.byType(FriendsPage), findsOneWidget);
    expect(find.text('Ольга Смирнова'), findsOneWidget);
    expect(find.text('Анна Соколова'), findsOneWidget);
    expect(find.text('2 друга'), findsOneWidget);
  });

  testWidgets('Search with no matches shows no-results state', (tester) async {
    final api = _apiWithFriends([]);
    final widget = await createTestApp(
      preferences: _basePrefs(),
      secureStorage: {'access_token': 'mock_token'},
      api: api,
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await _openFriends(tester);
    await tester.tap(find.byTooltip('Добавить друга'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'несуществующееимя');
    await tester.pump(const Duration(milliseconds: 400)); // debounce
    await tester.pumpAndSettle();

    expect(find.text('Никого не нашли'), findsOneWidget);
  });

  testWidgets('Already-added user shows В друзьях without add button', (
    tester,
  ) async {
    final api = _apiWithFriends(['u1']);
    final widget = await createTestApp(
      preferences: _basePrefs(),
      secureStorage: {'access_token': 'mock_token'},
      api: api,
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await _openFriends(tester);
    await tester.tap(find.byTooltip('Добавить друга'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'анна');
    await tester.pump(const Duration(milliseconds: 400)); // debounce
    await tester.pumpAndSettle();

    expect(find.text('Анна Соколова'), findsOneWidget);
    expect(find.text('В друзьях'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Добавить'), findsNothing);
  });

  testWidgets('Friend wish opens read-only details without edit/delete', (
    tester,
  ) async {
    final api = _apiWithFriends(['u1']);
    final widget = await createTestApp(
      preferences: _basePrefs(),
      secureStorage: {'access_token': 'mock_token'},
      api: api,
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await _openFriends(tester);

    await tester.tap(find.text('Анна Соколова'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Наушники Sony'));
    await tester.pumpAndSettle();

    expect(find.byType(FriendWishDetailsPage), findsOneWidget);
    // Read-only: нет edit/delete actions.
    expect(find.byTooltip('Редактировать'), findsNothing);
    expect(find.byTooltip('Удалить'), findsNothing);
    // Контент желания виден: цена, ссылка, заметка.
    expect(find.text('34 990 ₽'), findsOneWidget);
    expect(find.text('Заметка'), findsOneWidget);
    expect(find.textContaining('example.com/sony-xm6'), findsOneWidget);
  });

  testWidgets('Friend wish without link/price still renders', (tester) async {
    final api = _apiWithFriends(['u4']);
    final widget = await createTestApp(
      preferences: _basePrefs(),
      secureStorage: {'access_token': 'mock_token'},
      api: api,
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await _openFriends(tester);

    await tester.tap(find.text('Дмитрий Волков'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Поход в горы'));
    await tester.pumpAndSettle();

    expect(find.byType(FriendWishDetailsPage), findsOneWidget);
    expect(find.textContaining('Архыз'), findsOneWidget);
    // Нет ссылки — нет блока копирования.
    expect(find.text('Ссылка скопирована'), findsNothing);
  });

  testWidgets('Remove friend asks confirmation; cancel keeps friend', (
    tester,
  ) async {
    final api = _apiWithFriends(['u1', 'u2']);
    final widget = await createTestApp(
      preferences: _basePrefs(),
      secureStorage: {'access_token': 'mock_token'},
      api: api,
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await _openFriends(tester);

    await tester.tap(find.text('Максим Орлов'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Ещё'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить из друзей'));
    await tester.pumpAndSettle();

    expect(find.text('Удалить из друзей?'), findsOneWidget);
    await tester.tap(find.widgetWithText(AppButton, 'Отмена'));
    await tester.pumpAndSettle();

    // Отмена — остались на профиле, друг не удалён.
    expect(find.byType(FriendProfilePage), findsOneWidget);
    expect(find.text('Максим Орлов'), findsWidgets);
  });

  testWidgets('Remove friend confirmation removes only that friend', (
    tester,
  ) async {
    final api = _apiWithFriends(['u1', 'u2']);
    final widget = await createTestApp(
      preferences: _basePrefs(),
      secureStorage: {'access_token': 'mock_token'},
      api: api,
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await _openFriends(tester);

    await tester.tap(find.text('Максим Орлов'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ещё'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить из друзей'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, 'Удалить'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Вернулись на список; Максим удалён, Анна осталась.
    expect(find.byType(FriendsPage), findsOneWidget);
    expect(find.text('Максим Орлов'), findsNothing);
    expect(find.text('Анна Соколова'), findsOneWidget);
    expect(find.text('1 друг'), findsOneWidget);
    // DELETE доехал до сервера, связь снята симметрично.
    expect(api.friendsOf(_me), isNot(contains('u2')));
    expect(api.friendsOf('u2'), isNot(contains(_me)));
  });

  testWidgets('Two friends keep their wishes independent', (tester) async {
    final api = _apiWithFriends(['u1', 'u4']);
    final widget = await createTestApp(
      preferences: _basePrefs(),
      secureStorage: {'access_token': 'mock_token'},
      api: api,
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await _openFriends(tester);

    await tester.tap(find.text('Анна Соколова'));
    await tester.pumpAndSettle();
    // Пока кэша нет, открываем refresh → желания появляются.
    expect(find.textContaining('Наушники Sony'), findsOneWidget);
    expect(find.textContaining('Термокружка'), findsNothing);

    await tester.tap(find.byTooltip('Назад'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дмитрий Волков'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Термокружка'), findsOneWidget);
    expect(find.textContaining('Наушники Sony'), findsNothing);
  });

  testWidgets('Back from friend profile returns to friends root', (
    tester,
  ) async {
    final api = _apiWithFriends(['u1']);
    final widget = await createTestApp(
      preferences: _basePrefs(),
      secureStorage: {'access_token': 'mock_token'},
      api: api,
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await _openFriends(tester);
    await tester.tap(find.text('Анна Соколова'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Назад'));
    await tester.pumpAndSettle();

    expect(find.byType(FriendsPage), findsOneWidget);
    expect(find.text('Анна Соколова'), findsOneWidget);
  });

  testWidgets('Back from friend wish returns to friend profile', (
    tester,
  ) async {
    final api = _apiWithFriends(['u1']);
    final widget = await createTestApp(
      preferences: _basePrefs(),
      secureStorage: {'access_token': 'mock_token'},
      api: api,
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await _openFriends(tester);
    await tester.tap(find.text('Анна Соколова'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Наушники Sony'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Назад'));
    await tester.pumpAndSettle();

    expect(find.byType(FriendProfilePage), findsOneWidget);
    expect(find.textContaining('Мастер и Маргарита'), findsOneWidget);
  });

  testWidgets('Remove friend failure shows error and stays on profile', (
    tester,
  ) async {
    final api = _apiWithFriends(['u1', 'u2']);
    final widget = await createTestApp(
      preferences: _basePrefs(),
      secureStorage: {'access_token': 'mock_token'},
      api: api,
      overrides: [
        friendsRepositoryProvider.overrideWith(
          (ref) => _FailingFriendsRepository(
            DriftFriendsRepository(
              ref.read(appDatabaseProvider),
              ref.read(preferencesServiceProvider),
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await _openFriends(tester);

    await tester.tap(find.text('Максим Орлов'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ещё'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить из друзей'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, 'Удалить'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Ошибка показана, остались на профиле, друг не удалён.
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byType(FriendProfilePage), findsOneWidget);
    expect(find.text('Максим Орлов'), findsWidgets);
  });

  testWidgets('Add friend failure shows error snackbar', (tester) async {
    final api = _apiWithFriends([]);
    final widget = await createTestApp(
      preferences: _basePrefs(),
      secureStorage: {'access_token': 'mock_token'},
      api: api,
      overrides: [
        friendsRepositoryProvider.overrideWith(
          (ref) => _FailingFriendsRepository(
            DriftFriendsRepository(
              ref.read(appDatabaseProvider),
              ref.read(preferencesServiceProvider),
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await _openFriends(tester);
    await tester.tap(find.byTooltip('Добавить друга'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'анна');
    await tester.pump(const Duration(milliseconds: 400)); // debounce
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, 'Добавить'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(
      find.text('Не удалось добавить друга. Попробуйте ещё раз.'),
      findsOneWidget,
    );
  });
}

/// Репозиторий, который падает при мутациях — для проверки
/// error-path add/remove в UI. Чтения делегируются реальному
/// Drift-репозиторию.
class _FailingFriendsRepository implements FriendsRepository {
  _FailingFriendsRepository(this._inner);

  final FriendsRepository _inner;

  @override
  Stream<List<Friend>> watchFriends() => _inner.watchFriends();

  @override
  Future<List<Friend>> getFriends() => _inner.getFriends();

  @override
  Future<Friend?> getFriendById(String id) => _inner.getFriendById(id);

  @override
  Future<Friend> addFriend(Friend user) {
    return Future.error(
      const FriendNotFoundError(),
    );
  }

  @override
  Future<void> removeFriend(String id) {
    return Future.error(const FriendNotFoundError());
  }
}
