import 'dart:io';

import 'package:chtohochu/features/shopping/data/shopping_photo_picker.dart';
import 'package:chtohochu/features/shopping/presentation/pages/shopping_list_page.dart';
import 'package:chtohochu/features/shopping/presentation/widgets/shopping_item_composer.dart';
import 'package:chtohochu/features/wishes/data/wish_photo_picker.dart';
import 'package:chtohochu/shared/ui/buttons/app_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

/// Список с двумя позициями.
const _listJson =
    '[{"id":"l1","title":"Продукты","createdAt":"2025-01-01T00:00:00.000",'
    '"items":[{"id":"i1","title":"Молоко","quantity":1,"isChecked":false},'
    '{"id":"i2","title":"Хлеб","quantity":2,"isChecked":true}]}]';

Map<String, Object> _prefs() => {
  'onboarding_complete': true,
  'first_wish_flow_shown': true,
  'shopping_lists_cache': _listJson,
};

/// Фейковый источник фото: камера/галерея возвращают путь к реальному
/// временному PNG 1×1 (как в add_wish_sheet_test).
class _FakePicker implements WishPhotoPicker {
  _FakePicker({this.cancelCamera = false});

  final bool cancelCamera;

  int cameraCalls = 0;
  int galleryCalls = 0;
  int _count = 0;

  static const _png = <int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
    0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
    0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
    0x42, 0x60, 0x82,
  ];

  String _nextPath() {
    _count++;
    final file = File(
      '${Directory.systemTemp.path}/fake_item_photo_$_count.png',
    );
    // Синхронная запись: FakeAsync-зона widget-теста не дожидается
    // реального async IO.
    file.writeAsBytesSync(_png);
    return file.path;
  }

  @override
  Future<String?> capture() {
    cameraCalls++;
    return Future.value(cancelCamera ? null : _nextPath());
  }

  @override
  Future<List<String>> pickFromGallery() {
    galleryCalls++;
    return Future.value([_nextPath()]);
  }
}

Finder get _sendButton => find.ancestor(
  of: find.byTooltip('Добавить'),
  matching: find.byType(AppIconButton),
);

Finder get _attachButton => find.ancestor(
  of: find.byTooltip('Фото к позиции'),
  matching: find.byType(AppIconButton),
);

Finder get _previewRemove => find.byTooltip('Удалить фото');

bool _sendEnabled(WidgetTester tester) =>
    tester.widget<AppIconButton>(_sendButton).onPressed != null;

Future<void> _openListPage(WidgetTester tester, {_FakePicker? picker}) async {
  final widget = await createTestApp(
    preferences: _prefs(),
    secureStorage: {'access_token': 'mock_token'},
    overrides: [
      if (picker != null) shoppingPhotoPickerProvider.overrideWithValue(picker),
    ],
  );
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Покупки'));
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining('Продукты'));
  await tester.pumpAndSettle();
  expect(find.byType(ShoppingListPage), findsOneWidget);
}

void main() {
  testWidgets('Composer renders: attach, hint field, disabled send', (
    tester,
  ) async {
    await _openListPage(tester);

    expect(find.byType(ShoppingItemComposer), findsOneWidget);
    expect(_attachButton, findsOneWidget);
    expect(find.text('Что купить?'), findsOneWidget);
    expect(_sendEnabled(tester), isFalse);
  });

  testWidgets('Attach opens action sheet; dismiss does nothing', (
    tester,
  ) async {
    final picker = _FakePicker();
    await _openListPage(tester, picker: picker);

    await tester.tap(_attachButton);
    await tester.pumpAndSettle();
    expect(find.text('Фото к позиции'), findsOneWidget);
    expect(find.text('Камера'), findsOneWidget);
    expect(find.text('Галерея'), findsOneWidget);

    // Тап по barrier — sheet закрывается, picker не вызывался.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Камера'), findsNothing);
    expect(picker.cameraCalls, 0);
    expect(picker.galleryCalls, 0);
  });

  testWidgets('Camera → preview appears; remove disables send', (tester) async {
    final picker = _FakePicker();
    await _openListPage(tester, picker: picker);

    await tester.tap(_attachButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Камера'));
    await tester.pumpAndSettle();

    expect(picker.cameraCalls, 1);
    expect(_previewRemove, findsOneWidget);
    expect(_sendEnabled(tester), isTrue);

    await tester.tap(_previewRemove);
    await tester.pumpAndSettle();
    expect(_previewRemove, findsNothing);
    expect(_sendEnabled(tester), isFalse);
  });

  testWidgets('Gallery → preview appears', (tester) async {
    final picker = _FakePicker();
    await _openListPage(tester, picker: picker);

    await tester.tap(_attachButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Галерея'));
    await tester.pumpAndSettle();

    expect(picker.galleryCalls, 1);
    expect(_previewRemove, findsOneWidget);
  });

  testWidgets('Cancelled camera leaves composer empty', (tester) async {
    final picker = _FakePicker(cancelCamera: true);
    await _openListPage(tester, picker: picker);

    await tester.tap(_attachButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Камера'));
    await tester.pumpAndSettle();

    expect(picker.cameraCalls, 1);
    expect(_previewRemove, findsNothing);
    expect(_sendEnabled(tester), isFalse);
  });

  testWidgets('Text only → item appears; composer clears', (tester) async {
    await _openListPage(tester);

    await tester.enterText(find.byType(TextField), 'Кофе');
    await tester.pump();
    expect(_sendEnabled(tester), isTrue);
    await tester.tap(_sendButton);
    await tester.pumpAndSettle();

    expect(find.textContaining('Кофе'), findsOneWidget);
    expect(find.text('1 из 3 куплено'), findsOneWidget);
    // Поле очищено — placeholder снова виден.
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
  });

  testWidgets('Photo only → item with fallback title appears', (tester) async {
    final picker = _FakePicker();
    await _openListPage(tester, picker: picker);

    await tester.tap(_attachButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Галерея'));
    await tester.pumpAndSettle();
    expect(_previewRemove, findsOneWidget);

    await tester.tap(_sendButton);
    await tester.pumpAndSettle();

    // Фото-only позиция получила fallback-название и появилась в списке.
    expect(find.textContaining('Фотография'), findsOneWidget);
    expect(find.text('1 из 3 куплено'), findsOneWidget);
    // Preview сброшен после добавления.
    expect(_previewRemove, findsNothing);
  });

  testWidgets('Composer stays fully above the keyboard inset', (tester) async {
    await _openListPage(tester);

    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    const keyboard = 300.0;
    // FakeViewPadding задаётся в физических пикселях.
    tester.view.viewInsets = FakeViewPadding(
      bottom: keyboard * tester.view.devicePixelRatio,
    );
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();

    // Нижняя кромка composer — выше верхней кромки клавиатуры.
    final bottom = tester.getBottomLeft(find.byType(ShoppingItemComposer)).dy;
    expect(bottom, lessThanOrEqualTo(screenHeight - keyboard));

    // После закрытия клавиатуры composer возвращается к нижней кромке.
    tester.view.resetViewInsets();
    await tester.pump();
    final restored = tester.getBottomLeft(find.byType(ShoppingItemComposer)).dy;
    expect(restored, greaterThan(screenHeight - keyboard));
  });

  testWidgets('Text + photo → item appears; several adds in a row', (
    tester,
  ) async {
    final picker = _FakePicker();
    await _openListPage(tester, picker: picker);

    await tester.tap(_attachButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Камера'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Торт');
    await tester.pump();
    await tester.tap(_sendButton);
    await tester.pumpAndSettle();

    expect(find.textContaining('Торт'), findsOneWidget);
    expect(_previewRemove, findsNothing);

    // Следующие позиции подряд — composer остался рабочим.
    await tester.enterText(find.byType(TextField), 'Свечи');
    await tester.pump();
    await tester.tap(_sendButton);
    await tester.pumpAndSettle();

    expect(find.textContaining('Свечи'), findsOneWidget);
    expect(find.text('1 из 4 куплено'), findsOneWidget);
  });
}
