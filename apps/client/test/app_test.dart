import 'package:chtohochu/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Приложение собирается и отображает экран-заставку', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: ChtoHochuApp()));

    // Экран-заставка содержит CircularProgressIndicator.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
