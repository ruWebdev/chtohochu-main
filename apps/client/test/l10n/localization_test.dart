import 'package:chtohochu/features/auth/data/auth_repository.dart';
import 'package:chtohochu/features/friends/data/friends_repository.dart';
import 'package:chtohochu/features/profile/data/profile_repository.dart';
import 'package:chtohochu/features/shopping/data/shopping_repository.dart';
import 'package:chtohochu/features/wishes/data/wish_repository.dart';
import 'package:chtohochu/l10n/app_localizations_ru.dart';
import 'package:chtohochu/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Тесты архитектуры локализации.
///
/// Проверяют: единственный доступный locale, fallback на неподдерживаемую
/// локаль устройства, pluralization, параметры и маппинг типизированных
/// ошибок в локализованный текст.
void main() {
  final ru = AppLocalizationsRu();

  group('AppLocalizations', () {
    test('ru — единственный поддерживаемый locale', () {
      expect(AppLocalizations.supportedLocales, const [Locale('ru')]);
      expect(AppLocalizations.delegate.isSupported(const Locale('ru')), isTrue);
      expect(
        AppLocalizations.delegate.isSupported(const Locale('en')),
        isFalse,
      );
    });

    testWidgets('fallback: locale устройства вне supportedLocales → ru', (
      tester,
    ) async {
      // Явно просим «немецкий» — приложение должно отрендериться
      // на русском, без исключений при загрузке делегатов.
      late AppLocalizations l10n;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('de'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(l10n.localeName, 'ru');
      expect(l10n.appName, 'ЧтоХочу');
    });

    test('ICU plurals: желание/желания/желаний', () {
      expect(ru.wishesCount(1), '1 желание');
      expect(ru.wishesCount(2), '2 желания');
      expect(ru.wishesCount(5), '5 желаний');
      expect(ru.wishesCount(21), '21 желание');
      expect(ru.wishesCount(111), '111 желаний');
    });

    test('ICU plurals: список/списка/списков и позиции', () {
      expect(ru.listsCount(1), '1 список');
      expect(ru.listsCount(3), '3 списка');
      expect(ru.listsCount(10), '10 списков');
      expect(ru.itemsCount(1), '1 позиция');
      expect(ru.itemsCount(4), '4 позиции');
    });

    test('logout pending plural', () {
      expect(
        ru.logoutPendingMessage(1),
        '1 изменение ещё не отправлено на сервер. '
        'Если выйти сейчас, они будут удалены.',
      );
      expect(
        ru.logoutPendingMessage(3),
        '3 изменения ещё не отправлены на сервер. '
        'Если выйти сейчас, они будут удалены.',
      );
      expect(
        ru.logoutPendingMessage(7),
        '7 изменений ещё не отправлено на сервер. '
        'Если выйти сейчас, они будут удалены.',
      );
    });

    test('параметризованные строки', () {
      expect(
        ru.wishDeleteMessage('Книга'),
        '«Книга» будет удалено без возможности восстановления.',
      );
      expect(ru.listProgress(2, 5), '2 из 5 куплено');
      expect(ru.friendAddedSnack('Анна'), 'Анна добавлен(а) в друзья');
      expect(ru.versionLabel('2.0.0'), 'Версия 2.0.0');
      expect(
        ru.wishTitleTooLong(100),
        'Слишком длинное название (макс. 100 символов)',
      );
    });
  });

  group('error → l10n маппинг', () {
    test('auth errors', () {
      expect(
        authErrorMessage(ru, const InvalidCredentialsError()),
        'Неверный email или пароль',
      );
      expect(
        authErrorMessage(ru, const DuplicateAccountError()),
        'Аккаунт с таким email уже существует',
      );
      expect(
        authErrorMessage(ru, const AuthNetworkError()),
        'Проверьте подключение к интернету',
      );
      expect(
        authErrorMessage(ru, const UnknownAuthError()),
        'Произошла ошибка. Попробуйте ещё раз.',
      );
      // OAuth — текст зависит от кода провайдера.
      expect(
        authErrorMessage(ru, const OAuthUnavailableError('vk')),
        'Вход через VK скоро будет доступен.',
      );
      expect(
        authErrorMessage(ru, const OAuthUnavailableError('yandex')),
        'Вход через Яндекс скоро будет доступен.',
      );
      expect(
        authErrorMessage(ru, const OAuthFailedError('yandex')),
        'Не удалось войти через Яндекс.',
      );
      // Backend 422: текст от сервера — passthrough; без текста — fallback.
      expect(
        authErrorMessage(ru, const AuthValidationError('Email занят')),
        'Email занят',
      );
      expect(
        authErrorMessage(ru, const AuthValidationError()),
        'Ошибка валидации.',
      );
      // Необработанный Laravel-ключ не попадает на экран.
      expect(
        authErrorMessage(ru, const AuthValidationError('validation.required')),
        'Ошибка валидации.',
      );
    });

    test('domain errors', () {
      expect(
        wishErrorMessage(ru, const WishNotFoundError()),
        'Желание не найдено.',
      );
      expect(
        wishErrorMessage(ru, const UnknownWishError()),
        'Не удалось сохранить желание.',
      );
      expect(
        shoppingErrorMessage(ru, const ShoppingListNotFoundError()),
        'Список не найден.',
      );
      expect(
        shoppingErrorMessage(ru, const ShoppingItemNotFoundError()),
        'Позиция не найдена.',
      );
      expect(
        friendsErrorMessage(ru, const FriendNotFoundError()),
        'Пользователь не найден.',
      );
      expect(
        friendsErrorMessage(ru, const FriendsCannotAddSelfError()),
        'Нельзя добавить себя.',
      );
      expect(
        profileErrorMessage(ru, const ProfileNotFoundError()),
        'Профиль не найден.',
      );
      // Общие коды одинаковы во всех доменах.
      expect(
        wishErrorMessage(ru, const WishNotAuthenticatedError()),
        'Пользователь не авторизован.',
      );
    });
  });
}
