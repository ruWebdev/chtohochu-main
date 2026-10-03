/// Точка входа локализации приложения.
///
/// Сгенерированные классы (`gen_l10n`) + хелперы доступа +
/// маппинг типизированных domain-ошибок на локализованный текст.
///
/// Правила:
/// - UI получает строки через `context.l10n` / `AppLocalizations.of(context)`;
/// - domain/data слои бросают типизированные ошибки с техническими
///   кодами — текст выбирает presentation через `*ErrorMessage()`;
/// - backend-текст (422 validation message) показывается как есть —
///   backend уже локализует его сам.
library;

import 'package:flutter/widgets.dart';

import 'package:chtohochu/features/auth/data/auth_repository.dart';
import 'package:chtohochu/features/friends/data/friends_repository.dart';
import 'package:chtohochu/features/profile/data/profile_repository.dart';
import 'package:chtohochu/features/shopping/data/shopping_repository.dart';
import 'package:chtohochu/features/wishes/data/wish_repository.dart';
import 'package:chtohochu/l10n/app_localizations.dart';

export 'package:chtohochu/l10n/app_localizations.dart';

/// Сокращённый доступ: `context.l10n`.
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Пользовательский текст ошибки авторизации.
String authErrorMessage(AppLocalizations l10n, AuthError error) =>
    switch (error) {
      InvalidCredentialsError() => l10n.authInvalidCredentials,
      DuplicateAccountError() => l10n.authEmailTaken,
      AuthValidationError(:final serverMessage) =>
        _isTechnicalValidationKey(serverMessage)
            ? l10n.errorValidation
            : serverMessage!,
      OAuthUnavailableError(:final provider) =>
        provider == 'yandex'
            ? l10n.authYandexUnavailable
            : l10n.authVkUnavailable,
      OAuthFailedError(:final provider) =>
        provider == 'yandex' ? l10n.authYandexFailed : l10n.authVkFailed,
      AuthNetworkError() => l10n.authNetwork,
      UnknownAuthError() => l10n.authGeneric,
    };

/// Backend может отдать необработанный ключ перевода Laravel
/// (`validation.required`, `validation.min.string` и т.п.) — такой
/// текст технический и на экран не выводится, показываем fallback.
bool _isTechnicalValidationKey(String? message) =>
    message == null || message.startsWith('validation.');

/// Пользовательский текст ошибки желаний.
String wishErrorMessage(AppLocalizations l10n, WishError error) =>
    switch (error) {
      WishNetworkError() => l10n.errorSaveFailed,
      WishNotAuthenticatedError() => l10n.errorNotAuthenticated,
      WishNotFoundError() => l10n.wishNotFoundError,
      UnknownWishError() => l10n.wishSaveFailed,
    };

/// Пользовательский текст ошибки покупок.
String shoppingErrorMessage(AppLocalizations l10n, ShoppingError error) =>
    switch (error) {
      ShoppingStorageError() => l10n.errorSaveFailed,
      ShoppingNotAuthenticatedError() => l10n.errorNotAuthenticated,
      ShoppingListNotFoundError() => l10n.listNotFoundError,
      ShoppingItemNotFoundError() => l10n.itemNotFoundError,
      UnknownShoppingError() => l10n.listSaveFailed,
    };

/// Пользовательский текст ошибки друзей.
String friendsErrorMessage(AppLocalizations l10n, FriendsError error) =>
    switch (error) {
      FriendsNotAuthenticatedError() => l10n.errorNotAuthenticated,
      FriendsCannotAddSelfError() => l10n.friendCannotAddSelf,
      FriendNotFoundError() => l10n.friendUserNotFound,
      FriendsStorageError() => l10n.errorSaveFailed,
    };

/// Пользовательский текст ошибки профиля.
String profileErrorMessage(AppLocalizations l10n, ProfileError error) =>
    switch (error) {
      ProfileNotAuthenticatedError() => l10n.errorNotAuthenticated,
      ProfileNotFoundError() => l10n.profileNotFound,
      ProfileStorageError() => l10n.errorSaveFailed,
    };
