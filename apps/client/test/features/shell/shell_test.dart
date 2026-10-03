import 'package:chtohochu/features/friends/presentation/pages/friends_page.dart';
import 'package:chtohochu/features/profile/presentation/pages/profile_page.dart';
import 'package:chtohochu/features/shopping/presentation/pages/shopping_page.dart';
import 'package:chtohochu/features/wishes/presentation/pages/home_page.dart';
import 'package:chtohochu/shared/ui/navigation/app_bottom_bar.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

void main() {
  testWidgets('Shell shows bottom bar with 4 items', (tester) async {
    final widget = await createTestApp(
      preferences: {'onboarding_complete': true, 'first_wish_flow_shown': true},
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(find.byType(AppBottomBar), findsOneWidget);
    expect(find.text('Что хочу'), findsWidgets);
    expect(find.text('Покупки'), findsOneWidget);
    expect(find.text('Друзья'), findsOneWidget);
    expect(find.text('Профиль'), findsOneWidget);
  });

  testWidgets('Tapping Shopping tab navigates to shopping page', (
    tester,
  ) async {
    final widget = await createTestApp(
      preferences: {'onboarding_complete': true, 'first_wish_flow_shown': true},
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsOneWidget);

    await tester.tap(find.text('Покупки'));
    await tester.pumpAndSettle();

    expect(find.byType(ShoppingPage), findsOneWidget);
    expect(find.byType(AppBottomBar), findsOneWidget);
  });

  testWidgets('Tapping Friends tab navigates to friends page', (tester) async {
    final widget = await createTestApp(
      preferences: {'onboarding_complete': true, 'first_wish_flow_shown': true},
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Друзья'));
    await tester.pumpAndSettle();

    expect(find.byType(FriendsPage), findsOneWidget);
  });

  testWidgets('Tapping Profile tab navigates to profile page', (tester) async {
    final widget = await createTestApp(
      preferences: {'onboarding_complete': true, 'first_wish_flow_shown': true},
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Профиль'));
    await tester.pumpAndSettle();

    expect(find.byType(ProfilePage), findsOneWidget);
  });

  testWidgets('Switching tabs back to home preserves bottom bar', (
    tester,
  ) async {
    final widget = await createTestApp(
      preferences: {'onboarding_complete': true, 'first_wish_flow_shown': true},
      secureStorage: {'access_token': 'mock_token'},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    // Home → Shopping → Friends → Home
    await tester.tap(find.text('Покупки'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Друзья'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Что хочу'));
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(AppBottomBar), findsOneWidget);
  });

  testWidgets('Bottom bar does not appear on auth page', (tester) async {
    final widget = await createTestApp(
      preferences: {'onboarding_complete': true},
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(find.byType(AppBottomBar), findsNothing);
  });
}
