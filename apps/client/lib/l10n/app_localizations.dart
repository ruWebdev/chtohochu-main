import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('ru')];

  /// Product brand name. Keep untranslated if the brand is not localized.
  ///
  /// In ru, this message translates to:
  /// **'ЧтоХочу'**
  String get appName;

  /// Generic confirmation button
  ///
  /// In ru, this message translates to:
  /// **'OK'**
  String get ok;

  /// Cancel button in dialogs
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get cancel;

  /// Button or tooltip that closes the current dialog or screen
  ///
  /// In ru, this message translates to:
  /// **'Закрыть'**
  String get close;

  /// Back navigation button tooltip and semantic label
  ///
  /// In ru, this message translates to:
  /// **'Назад'**
  String get back;

  /// Overflow menu button tooltip and semantic label
  ///
  /// In ru, this message translates to:
  /// **'Ещё'**
  String get more;

  /// Title of the notifications page and label of the bell action
  ///
  /// In ru, this message translates to:
  /// **'Оповещения'**
  String get notificationsTitle;

  /// Empty state title on the notifications page
  ///
  /// In ru, this message translates to:
  /// **'Пока нет оповещений'**
  String get notificationsEmptyTitle;

  /// Empty state description on the notifications page
  ///
  /// In ru, this message translates to:
  /// **'Здесь будут появляться оповещения.'**
  String get notificationsEmptyDescription;

  /// Generic save button
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get save;

  /// Save button when editing an existing entity
  ///
  /// In ru, this message translates to:
  /// **'Сохранить изменения'**
  String get saveChanges;

  /// Generic delete button and tooltip
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get delete;

  /// Generic edit tooltip
  ///
  /// In ru, this message translates to:
  /// **'Редактировать'**
  String get edit;

  /// Generic add button
  ///
  /// In ru, this message translates to:
  /// **'Добавить'**
  String get add;

  /// Button that retries loading a list
  ///
  /// In ru, this message translates to:
  /// **'Обновить'**
  String get refresh;

  /// Button that skips an optional step
  ///
  /// In ru, this message translates to:
  /// **'Пропустить'**
  String get skip;

  /// Divider label between login form and OAuth buttons
  ///
  /// In ru, this message translates to:
  /// **'или'**
  String get orSeparator;

  /// Generic retry hint text
  ///
  /// In ru, this message translates to:
  /// **'Попробуйте ещё раз.'**
  String get tryAgain;

  /// Title shown when a list fails to load
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить'**
  String get loadFailed;

  /// Hint under the load-failed title
  ///
  /// In ru, this message translates to:
  /// **'Потяните вниз, чтобы обновить.'**
  String get pullToRefresh;

  /// Inline suffix in wishes subtitle shown when local changes have not been synced
  ///
  /// In ru, this message translates to:
  /// **'не синхронизировано'**
  String get syncNotSynced;

  /// Fallback display name for a user without a name
  ///
  /// In ru, this message translates to:
  /// **'Без имени'**
  String get noName;

  /// Placeholder for URL input fields
  ///
  /// In ru, this message translates to:
  /// **'https://…'**
  String get urlHint;

  /// Error shown when a local mutation fails
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить. Проверьте интернет.'**
  String get errorSaveFailed;

  /// Error shown when an action requires a signed-in user
  ///
  /// In ru, this message translates to:
  /// **'Пользователь не авторизован.'**
  String get errorNotAuthenticated;

  /// Fallback when a server validation error has no readable message
  ///
  /// In ru, this message translates to:
  /// **'Ошибка валидации.'**
  String get errorValidation;

  /// Fallback for unexpected errors
  ///
  /// In ru, this message translates to:
  /// **'Произошла ошибка. Попробуйте ещё раз.'**
  String get errorGeneric;

  /// Bottom navigation label for the wishes section
  ///
  /// In ru, this message translates to:
  /// **'Что хочу'**
  String get navWishes;

  /// Bottom navigation label for the shopping section
  ///
  /// In ru, this message translates to:
  /// **'Покупки'**
  String get navShopping;

  /// Bottom navigation label for the friends section
  ///
  /// In ru, this message translates to:
  /// **'Друзья'**
  String get navFriends;

  /// Bottom navigation label for the profile section
  ///
  /// In ru, this message translates to:
  /// **'Профиль'**
  String get navProfile;

  /// Static product tagline under the app name on the auth screen
  ///
  /// In ru, this message translates to:
  /// **'Твоё пространство желаний'**
  String get authTagline;

  /// Subtitle under the logo in login mode
  ///
  /// In ru, this message translates to:
  /// **'Войдите, чтобы продолжить'**
  String get authSubtitleLogin;

  /// Subtitle under the logo in registration mode
  ///
  /// In ru, this message translates to:
  /// **'Создайте аккаунт за минуту'**
  String get authSubtitleRegister;

  /// Login tab in the mode toggle
  ///
  /// In ru, this message translates to:
  /// **'Вход'**
  String get authTabLogin;

  /// Registration tab in the mode toggle
  ///
  /// In ru, this message translates to:
  /// **'Регистрация'**
  String get authTabRegister;

  /// Name field label in registration mode
  ///
  /// In ru, this message translates to:
  /// **'Имя (необязательно)'**
  String get authNameLabel;

  /// Name field placeholder in registration mode
  ///
  /// In ru, this message translates to:
  /// **'Как вас зовут'**
  String get authNameHint;

  /// Accessibility label for the name field
  ///
  /// In ru, this message translates to:
  /// **'Имя'**
  String get authNameSemantic;

  /// Email field label
  ///
  /// In ru, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// Accessibility label for the email field
  ///
  /// In ru, this message translates to:
  /// **'Адрес электронной почты'**
  String get emailSemantic;

  /// Email field placeholder
  ///
  /// In ru, this message translates to:
  /// **'you@example.com'**
  String get emailHint;

  /// Password field label
  ///
  /// In ru, this message translates to:
  /// **'Пароль'**
  String get passwordLabel;

  /// Password field placeholder
  ///
  /// In ru, this message translates to:
  /// **'Минимум 6 символов'**
  String get passwordHint;

  /// Accessibility label for the password field
  ///
  /// In ru, this message translates to:
  /// **'Пароль'**
  String get passwordSemantic;

  /// Tooltip for the password visibility toggle (hidden state)
  ///
  /// In ru, this message translates to:
  /// **'Показать пароль'**
  String get showPassword;

  /// Tooltip for the password visibility toggle (visible state)
  ///
  /// In ru, this message translates to:
  /// **'Скрыть пароль'**
  String get hidePassword;

  /// Primary button in login mode
  ///
  /// In ru, this message translates to:
  /// **'Войти'**
  String get authLoginButton;

  /// Primary button in registration mode
  ///
  /// In ru, this message translates to:
  /// **'Создать аккаунт'**
  String get authRegisterButton;

  /// OAuth button for VK
  ///
  /// In ru, this message translates to:
  /// **'Войти через VK'**
  String get authVkButton;

  /// OAuth button for Yandex
  ///
  /// In ru, this message translates to:
  /// **'Войти через Яндекс'**
  String get authYandexButton;

  /// Validation error under the email field
  ///
  /// In ru, this message translates to:
  /// **'Введите корректный email'**
  String get emailInvalid;

  /// Validation error under the password field
  ///
  /// In ru, this message translates to:
  /// **'Пароль не короче 8 символов'**
  String get passwordTooShort;

  /// Error after a 401 response on login
  ///
  /// In ru, this message translates to:
  /// **'Неверный email или пароль'**
  String get authInvalidCredentials;

  /// Error after a 422 duplicate-email response on registration
  ///
  /// In ru, this message translates to:
  /// **'Аккаунт с таким email уже существует'**
  String get authEmailTaken;

  /// Error when the auth request cannot reach the server
  ///
  /// In ru, this message translates to:
  /// **'Проверьте подключение к интернету'**
  String get authNetwork;

  /// Unexpected auth failure
  ///
  /// In ru, this message translates to:
  /// **'Произошла ошибка. Попробуйте ещё раз.'**
  String get authGeneric;

  /// Unexpected failure of the VK OAuth flow
  ///
  /// In ru, this message translates to:
  /// **'Не удалось войти через VK.'**
  String get authVkFailed;

  /// Unexpected failure of the Yandex OAuth flow
  ///
  /// In ru, this message translates to:
  /// **'Не удалось войти через Яндекс.'**
  String get authYandexFailed;

  /// Shown while VK OAuth is not implemented yet
  ///
  /// In ru, this message translates to:
  /// **'Вход через VK скоро будет доступен.'**
  String get authVkUnavailable;

  /// Shown while Yandex OAuth is not implemented yet
  ///
  /// In ru, this message translates to:
  /// **'Вход через Яндекс скоро будет доступен.'**
  String get authYandexUnavailable;

  /// Informational note shown when tapping a not-yet-implemented OAuth button
  ///
  /// In ru, this message translates to:
  /// **'Вход через соцсети скоро будет доступен'**
  String get oauthUnavailableTitle;

  /// Skip button in the onboarding top bar
  ///
  /// In ru, this message translates to:
  /// **'Пропустить'**
  String get onboardingSkip;

  /// Next-slide button
  ///
  /// In ru, this message translates to:
  /// **'Далее'**
  String get onboardingNext;

  /// Button on the last onboarding slide
  ///
  /// In ru, this message translates to:
  /// **'Начать'**
  String get onboardingStart;

  /// Title of onboarding slide 1
  ///
  /// In ru, this message translates to:
  /// **'ЧтоХочу — место, куда ты складываешь то, чего хочешь'**
  String get onboardingSlide1Title;

  /// Description of onboarding slide 1
  ///
  /// In ru, this message translates to:
  /// **'Записывайте свои желания в одном месте, чтобы ничего не потерялось.'**
  String get onboardingSlide1Description;

  /// Title of onboarding slide 2
  ///
  /// In ru, this message translates to:
  /// **'Чтобы самому не забыть'**
  String get onboardingSlide2Title;

  /// Description of onboarding slide 2
  ///
  /// In ru, this message translates to:
  /// **'Добавляйте идеи подарков, вещи и мечты — они всегда будут под рукой.'**
  String get onboardingSlide2Description;

  /// Title of onboarding slide 3
  ///
  /// In ru, this message translates to:
  /// **'И чтобы близким было проще понять, что подарить'**
  String get onboardingSlide3Title;

  /// Description of onboarding slide 3
  ///
  /// In ru, this message translates to:
  /// **'Поделитесь списком — и получите именно то, чего вы действительно хотите.'**
  String get onboardingSlide3Description;

  /// Title of the wishes list screen
  ///
  /// In ru, this message translates to:
  /// **'Что хочу'**
  String get wishesTitle;

  /// Wish counter under the screen title
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} желание} few{{count} желания} many{{count} желаний} other{{count} желаний}}'**
  String wishesCount(int count);

  /// Plus action in the wishes app bar (tooltip and semantic label)
  ///
  /// In ru, this message translates to:
  /// **'Добавить желание'**
  String get wishAdd;

  /// Button in the empty wishes state
  ///
  /// In ru, this message translates to:
  /// **'Добавить первое желание'**
  String get wishAddFirst;

  /// Empty state title on the wishes screen
  ///
  /// In ru, this message translates to:
  /// **'Что ты хочешь?'**
  String get wishesEmptyTitle;

  /// Empty state description on the wishes screen
  ///
  /// In ru, this message translates to:
  /// **'Запиши, чего хочешь, — чтобы не забыть и чтобы близким было проще выбрать подарок.'**
  String get wishesEmptyDescription;

  /// Empty wishes title inside a friend profile
  ///
  /// In ru, this message translates to:
  /// **'Пока нет желаний'**
  String get friendWishesEmptyTitle;

  /// Empty state when a wish id no longer exists
  ///
  /// In ru, this message translates to:
  /// **'Желание не найдено'**
  String get wishNotFound;

  /// Empty state description for a missing wish
  ///
  /// In ru, this message translates to:
  /// **'Возможно, оно было удалено.'**
  String get wishNotFoundHint;

  /// Empty state description for a missing friend's wish
  ///
  /// In ru, this message translates to:
  /// **'Возможно, оно было удалено владельцем.'**
  String get wishNotFoundByOwner;

  /// Button returning to the wishes list
  ///
  /// In ru, this message translates to:
  /// **'К списку'**
  String get backToList;

  /// Form title when editing a wish
  ///
  /// In ru, this message translates to:
  /// **'Редактировать желание'**
  String get wishEditTitle;

  /// Semantic label for the edit-wish action
  ///
  /// In ru, this message translates to:
  /// **'Редактировать желание'**
  String get wishEditSemantic;

  /// Form title when creating a wish
  ///
  /// In ru, this message translates to:
  /// **'Новое желание'**
  String get wishNewTitle;

  /// Wish title field label
  ///
  /// In ru, this message translates to:
  /// **'Что вы хотите?'**
  String get wishTitleLabel;

  /// Wish title field placeholder
  ///
  /// In ru, this message translates to:
  /// **'Например: наушники Sony WH-1000XM6'**
  String get wishTitleHint;

  /// Accessibility label for the wish title field
  ///
  /// In ru, this message translates to:
  /// **'Название желания'**
  String get wishTitleSemantic;

  /// Wish price field label
  ///
  /// In ru, this message translates to:
  /// **'Цена, ₽ (необязательно)'**
  String get wishPriceLabel;

  /// Wish price field placeholder
  ///
  /// In ru, this message translates to:
  /// **'12 990'**
  String get wishPriceHint;

  /// Accessibility label for the wish price field
  ///
  /// In ru, this message translates to:
  /// **'Примерная цена в рублях'**
  String get wishPriceSemantic;

  /// Product link field label
  ///
  /// In ru, this message translates to:
  /// **'Ссылка на товар (необязательно)'**
  String get wishLinkLabel;

  /// Accessibility label for the product link field
  ///
  /// In ru, this message translates to:
  /// **'Ссылка на товар'**
  String get wishLinkSemantic;

  /// Image link field label
  ///
  /// In ru, this message translates to:
  /// **'Ссылка на изображение (необязательно)'**
  String get wishImageLabel;

  /// Accessibility label for the image link field
  ///
  /// In ru, this message translates to:
  /// **'Ссылка на изображение'**
  String get wishImageSemantic;

  /// Note field label in the wish form
  ///
  /// In ru, this message translates to:
  /// **'Заметка (необязательно)'**
  String get wishNoteLabel;

  /// Note field placeholder
  ///
  /// In ru, this message translates to:
  /// **'Размер, цвет, детали…'**
  String get wishNoteHint;

  /// Accessibility label for the note field
  ///
  /// In ru, this message translates to:
  /// **'Заметка о желании'**
  String get wishNoteSemantic;

  /// Validation error when the wish title is empty
  ///
  /// In ru, this message translates to:
  /// **'Введите название желания'**
  String get wishTitleRequired;

  /// Validation error when the wish title exceeds the limit
  ///
  /// In ru, this message translates to:
  /// **'Слишком длинное название (макс. {max} символов)'**
  String wishTitleTooLong(int max);

  /// Validation error for a non-numeric price
  ///
  /// In ru, this message translates to:
  /// **'Введите цену числом'**
  String get wishPriceInvalid;

  /// Primary button when creating a wish
  ///
  /// In ru, this message translates to:
  /// **'Сохранить желание'**
  String get wishSave;

  /// Title of the delete-wish confirmation dialog
  ///
  /// In ru, this message translates to:
  /// **'Удалить желание?'**
  String get wishDeleteTitle;

  /// Body of the delete-wish confirmation dialog
  ///
  /// In ru, this message translates to:
  /// **'«{title}» будет удалено без возможности восстановления.'**
  String wishDeleteMessage(String title);

  /// Semantic label for the delete-wish action
  ///
  /// In ru, this message translates to:
  /// **'Удалить желание'**
  String get wishDeleteSemantic;

  /// SnackBar shown after copying a wish link
  ///
  /// In ru, this message translates to:
  /// **'Ссылка скопирована'**
  String get linkCopied;

  /// Section label above the wish note on the details screen
  ///
  /// In ru, this message translates to:
  /// **'Заметка'**
  String get noteSection;

  /// Creation date caption on the wish details screen
  ///
  /// In ru, this message translates to:
  /// **'Добавлено {date}'**
  String wishAddedOn(String date);

  /// Unexpected error while saving a wish
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить желание.'**
  String get wishSaveFailed;

  /// SnackBar when deleting a wish fails
  ///
  /// In ru, this message translates to:
  /// **'Не удалось удалить желание.'**
  String get wishDeleteFailed;

  /// Error when the wish to update no longer exists
  ///
  /// In ru, this message translates to:
  /// **'Желание не найдено.'**
  String get wishNotFoundError;

  /// Title of the first-wish onboarding step
  ///
  /// In ru, this message translates to:
  /// **'Создай своё первое желание'**
  String get firstWishTitle;

  /// Description of the first-wish onboarding step
  ///
  /// In ru, this message translates to:
  /// **'Запишите то, чего вы хотите — чтобы не забыть самим и помочь близким выбрать правильный подарок.'**
  String get firstWishDescription;

  /// Placeholder of the main field in the quick add-wish sheet
  ///
  /// In ru, this message translates to:
  /// **'Что хочешь?'**
  String get wishQuickHint;

  /// Secondary button that reveals the link field in the add-wish sheet
  ///
  /// In ru, this message translates to:
  /// **'URL'**
  String get wishUrlAction;

  /// Accessibility label for the add-link button
  ///
  /// In ru, this message translates to:
  /// **'Добавить ссылку'**
  String get wishUrlActionSemantic;

  /// Label of the link field in the add-wish sheet
  ///
  /// In ru, this message translates to:
  /// **'Ссылка'**
  String get wishUrlLabel;

  /// Validation error for a malformed URL in the add-wish sheet
  ///
  /// In ru, this message translates to:
  /// **'Некорректная ссылка'**
  String get wishUrlInvalid;

  /// Secondary button that opens the camera in the add-wish sheet
  ///
  /// In ru, this message translates to:
  /// **'Камера'**
  String get wishCameraAction;

  /// Accessibility label for the camera button
  ///
  /// In ru, this message translates to:
  /// **'Сфотографировать желание'**
  String get wishCameraActionSemantic;

  /// Secondary button that opens the system gallery picker in the add-wish sheet
  ///
  /// In ru, this message translates to:
  /// **'Галерея'**
  String get wishGalleryAction;

  /// Accessibility label for the gallery button
  ///
  /// In ru, this message translates to:
  /// **'Выбрать фото из галереи'**
  String get wishGalleryActionSemantic;

  /// Accessibility label for removing a photo in the add-wish sheet
  ///
  /// In ru, this message translates to:
  /// **'Удалить фото'**
  String get wishPhotoRemove;

  /// Error shown when camera capture fails
  ///
  /// In ru, this message translates to:
  /// **'Не удалось получить фото.'**
  String get wishPhotoError;

  /// Title for a wish created from a photo without text
  ///
  /// In ru, this message translates to:
  /// **'Фотография'**
  String get wishPhotoFallbackTitle;

  /// Title of the dialog when closing a filled add-wish sheet
  ///
  /// In ru, this message translates to:
  /// **'Закрыть без сохранения?'**
  String get wishDiscardTitle;

  /// Body of the dialog when closing a filled add-wish sheet
  ///
  /// In ru, this message translates to:
  /// **'Введённые данные будут потеряны.'**
  String get wishDiscardMessage;

  /// Title of the shopping lists screen
  ///
  /// In ru, this message translates to:
  /// **'Покупки'**
  String get shoppingTitle;

  /// Shopping-list counter under the screen title
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} список} few{{count} списка} many{{count} списков} other{{count} списков}}'**
  String listsCount(int count);

  /// Shopping-item counter
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} позиция} few{{count} позиции} many{{count} позиций} other{{count} позиций}}'**
  String itemsCount(int count);

  /// Plus action in the shopping app bar (tooltip and semantic label)
  ///
  /// In ru, this message translates to:
  /// **'Создать список покупок'**
  String get listAdd;

  /// Empty state title on the shopping screen
  ///
  /// In ru, this message translates to:
  /// **'Пока нет списков'**
  String get listsEmptyTitle;

  /// Empty state description on the shopping screen
  ///
  /// In ru, this message translates to:
  /// **'Создавайте списки покупок — продукты на неделю, в поездку, для дома — и отмечайте купленное.'**
  String get listsEmptyDescription;

  /// Primary button when creating a shopping list
  ///
  /// In ru, this message translates to:
  /// **'Создать список'**
  String get listCreate;

  /// Form title and action label when renaming a list
  ///
  /// In ru, this message translates to:
  /// **'Переименовать список'**
  String get listRename;

  /// Form title when creating a shopping list
  ///
  /// In ru, this message translates to:
  /// **'Новый список'**
  String get listNewTitle;

  /// List title field label
  ///
  /// In ru, this message translates to:
  /// **'Название списка'**
  String get listTitleLabel;

  /// List title field placeholder
  ///
  /// In ru, this message translates to:
  /// **'Например: продукты на неделю'**
  String get listTitleHint;

  /// Validation error when the list title is empty
  ///
  /// In ru, this message translates to:
  /// **'Введите название списка'**
  String get listTitleRequired;

  /// Validation error when the list title exceeds the limit
  ///
  /// In ru, this message translates to:
  /// **'Слишком длинное название (макс. {max} символов)'**
  String listTitleTooLong(int max);

  /// Title of the delete-list confirmation dialog
  ///
  /// In ru, this message translates to:
  /// **'Удалить список?'**
  String get listDeleteTitle;

  /// Body of the delete-list confirmation dialog
  ///
  /// In ru, this message translates to:
  /// **'«{title}» и все его позиции будут удалены без возможности восстановления.'**
  String listDeleteMessage(String title);

  /// Semantic label for the delete-list action
  ///
  /// In ru, this message translates to:
  /// **'Удалить список'**
  String get listDeleteSemantic;

  /// Tooltip for the rename-list action
  ///
  /// In ru, this message translates to:
  /// **'Переименовать'**
  String get listRenameTooltip;

  /// Empty state when a list id no longer exists
  ///
  /// In ru, this message translates to:
  /// **'Список не найден'**
  String get listNotFound;

  /// Empty state description for a missing list
  ///
  /// In ru, this message translates to:
  /// **'Возможно, он был удалён.'**
  String get listNotFoundHint;

  /// Button returning to the shopping lists
  ///
  /// In ru, this message translates to:
  /// **'К спискам'**
  String get backToLists;

  /// Progress caption when every item is checked
  ///
  /// In ru, this message translates to:
  /// **'Всё куплено'**
  String get listAllDone;

  /// Progress caption when the list has no items
  ///
  /// In ru, this message translates to:
  /// **'Список пуст'**
  String get listEmpty;

  /// Card caption for a list without items
  ///
  /// In ru, this message translates to:
  /// **'Пока пусто'**
  String get listEmptyHint;

  /// Progress caption: checked out of total items bought
  ///
  /// In ru, this message translates to:
  /// **'{checked} из {total} куплено'**
  String listProgress(int checked, int total);

  /// Hint shown inside an empty shopping list
  ///
  /// In ru, this message translates to:
  /// **'В списке пока ничего нет'**
  String get listEmptyItems;

  /// Row that opens the inline add-item field
  ///
  /// In ru, this message translates to:
  /// **'Добавить товар'**
  String get itemAdd;

  /// Placeholder and accessibility label for the quick-add item field
  ///
  /// In ru, this message translates to:
  /// **'Название товара'**
  String get itemTitleHint;

  /// Accessibility label for the button that collapses the add-item field
  ///
  /// In ru, this message translates to:
  /// **'Закрыть поле добавления'**
  String get itemAddCloseSemantic;

  /// Title of the item edit bottom sheet
  ///
  /// In ru, this message translates to:
  /// **'Позиция'**
  String get itemSheetTitle;

  /// Item title field label
  ///
  /// In ru, this message translates to:
  /// **'Название'**
  String get itemNameLabel;

  /// Item quantity field label
  ///
  /// In ru, this message translates to:
  /// **'Количество'**
  String get itemQuantityLabel;

  /// Unexpected error while saving a shopping list
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить список.'**
  String get listSaveFailed;

  /// Error when the list no longer exists
  ///
  /// In ru, this message translates to:
  /// **'Список не найден.'**
  String get listNotFoundError;

  /// Error when the item no longer exists
  ///
  /// In ru, this message translates to:
  /// **'Позиция не найдена.'**
  String get itemNotFoundError;

  /// Title of the friends screen
  ///
  /// In ru, this message translates to:
  /// **'Друзья'**
  String get friendsTitle;

  /// Friend counter under the screen title
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} друг} few{{count} друга} many{{count} друзей} other{{count} друзей}}'**
  String friendsCount(int count);

  /// Add-friend action: screen title, tooltip, button
  ///
  /// In ru, this message translates to:
  /// **'Добавить друга'**
  String get friendAdd;

  /// Empty state title on the friends screen
  ///
  /// In ru, this message translates to:
  /// **'Пока нет друзей'**
  String get friendsEmptyTitle;

  /// Empty state description on the friends screen
  ///
  /// In ru, this message translates to:
  /// **'Добавьте близких, чтобы видеть их желания и проще выбирать подарки.'**
  String get friendsEmptyDescription;

  /// Placeholder of the friend search field
  ///
  /// In ru, this message translates to:
  /// **'Имя или @username'**
  String get friendSearchHint;

  /// Hint title before the first search query
  ///
  /// In ru, this message translates to:
  /// **'Найдите друга'**
  String get friendSearchEmptyTitle;

  /// Hint description before the first search query
  ///
  /// In ru, this message translates to:
  /// **'Введите имя или @username — человек появится в результатах поиска.'**
  String get friendSearchEmptyDescription;

  /// Title shown when friend search fails
  ///
  /// In ru, this message translates to:
  /// **'Не удалось выполнить поиск'**
  String get friendSearchFailed;

  /// Empty state title when search returns no users
  ///
  /// In ru, this message translates to:
  /// **'Никого не нашли'**
  String get friendSearchNoResults;

  /// Empty state description when search returns no users
  ///
  /// In ru, this message translates to:
  /// **'По запросу «{query}» нет пользователей. Проверьте имя или username.'**
  String friendSearchNoResultsHint(String query);

  /// Trailing label for a user added during this session
  ///
  /// In ru, this message translates to:
  /// **'Добавлен'**
  String get friendAdded;

  /// Trailing label for a user who is already a friend
  ///
  /// In ru, this message translates to:
  /// **'В друзьях'**
  String get friendAlready;

  /// SnackBar shown after adding a friend
  ///
  /// In ru, this message translates to:
  /// **'{name} добавлен(а) в друзья'**
  String friendAddedSnack(String name);

  /// SnackBar shown when adding a friend fails
  ///
  /// In ru, this message translates to:
  /// **'Не удалось добавить друга. Попробуйте ещё раз.'**
  String get friendAddFailed;

  /// SnackBar when removing a friend fails
  ///
  /// In ru, this message translates to:
  /// **'Не удалось удалить друга.'**
  String get friendRemoveFailed;

  /// Title of the remove-friend confirmation dialog
  ///
  /// In ru, this message translates to:
  /// **'Удалить из друзей?'**
  String get friendRemoveTitle;

  /// Body of the remove-friend confirmation dialog
  ///
  /// In ru, this message translates to:
  /// **'{name} исчезнет из вашего списка друзей. Вы сможете добавить его снова через поиск.'**
  String friendRemoveMessage(String name);

  /// Semantic label for the remove-friend action
  ///
  /// In ru, this message translates to:
  /// **'Удалить из друзей'**
  String get friendRemove;

  /// Empty state when a friend id no longer exists
  ///
  /// In ru, this message translates to:
  /// **'Друг не найден'**
  String get friendNotFound;

  /// Empty state description for a missing friend
  ///
  /// In ru, this message translates to:
  /// **'Возможно, он был удалён из списка.'**
  String get friendNotFoundHint;

  /// Button returning to the friends list
  ///
  /// In ru, this message translates to:
  /// **'К списку друзей'**
  String get backToFriends;

  /// Button returning to the friend profile
  ///
  /// In ru, this message translates to:
  /// **'К профилю друга'**
  String get backToFriend;

  /// Section header on the friend profile when the friend has no wishes
  ///
  /// In ru, this message translates to:
  /// **'Желания'**
  String get wishesSection;

  /// Section header on the friend profile with a wish counter
  ///
  /// In ru, this message translates to:
  /// **'Желания · {count, plural, one{{count} желание} few{{count} желания} many{{count} желаний} other{{count} желаний}}'**
  String wishesSectionCount(int count);

  /// Empty state inside a friend profile
  ///
  /// In ru, this message translates to:
  /// **'{name} ещё не добавил(а) желания, которые вам видны.'**
  String friendNoWishes(String name);

  /// Error when the searched user does not exist
  ///
  /// In ru, this message translates to:
  /// **'Пользователь не найден.'**
  String get friendUserNotFound;

  /// Error when trying to add yourself as a friend
  ///
  /// In ru, this message translates to:
  /// **'Нельзя добавить себя.'**
  String get friendCannotAddSelf;

  /// Title of the profile screen
  ///
  /// In ru, this message translates to:
  /// **'Профиль'**
  String get profileTitle;

  /// Button and screen title for editing the profile
  ///
  /// In ru, this message translates to:
  /// **'Редактировать профиль'**
  String get profileEdit;

  /// Section label for app settings
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get settingsSection;

  /// Section label for account actions
  ///
  /// In ru, this message translates to:
  /// **'Аккаунт'**
  String get accountSection;

  /// Section label for app info
  ///
  /// In ru, this message translates to:
  /// **'О приложении'**
  String get aboutSection;

  /// Theme picker row title and sheet title
  ///
  /// In ru, this message translates to:
  /// **'Внешний вид'**
  String get appearance;

  /// System theme option
  ///
  /// In ru, this message translates to:
  /// **'Системная'**
  String get themeSystem;

  /// Light theme option
  ///
  /// In ru, this message translates to:
  /// **'Светлая'**
  String get themeLight;

  /// Dark theme option
  ///
  /// In ru, this message translates to:
  /// **'Тёмная'**
  String get themeDark;

  /// Logout row and confirm button
  ///
  /// In ru, this message translates to:
  /// **'Выйти'**
  String get logout;

  /// Title of the logout confirmation dialog
  ///
  /// In ru, this message translates to:
  /// **'Выйти из аккаунта?'**
  String get logoutTitle;

  /// Body of the logout confirmation dialog
  ///
  /// In ru, this message translates to:
  /// **'Вы сможете войти снова позже.'**
  String get logoutMessage;

  /// Title of the destructive logout dialog when outbox is not empty
  ///
  /// In ru, this message translates to:
  /// **'Несохранённые изменения'**
  String get logoutPendingTitle;

  /// Body of the destructive logout dialog; warns that pending sync changes will be lost
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} изменение ещё не отправлено на сервер.} few{{count} изменения ещё не отправлены на сервер.} many{{count} изменений ещё не отправлено на сервер.} other{{count} изменений ещё не отправлено на сервер.}} Если выйти сейчас, они будут удалены.'**
  String logoutPendingMessage(int count);

  /// Confirm button of the destructive logout dialog
  ///
  /// In ru, this message translates to:
  /// **'Удалить и выйти'**
  String get logoutPendingConfirm;

  /// App version subtitle in the About section
  ///
  /// In ru, this message translates to:
  /// **'Версия {version}'**
  String versionLabel(String version);

  /// Name field label in the profile editor
  ///
  /// In ru, this message translates to:
  /// **'Имя'**
  String get nameLabel;

  /// Name field placeholder in the profile editor
  ///
  /// In ru, this message translates to:
  /// **'Как вас видят друзья'**
  String get nameHintProfile;

  /// Validation error when the profile name is empty
  ///
  /// In ru, this message translates to:
  /// **'Укажите имя'**
  String get nameRequired;

  /// Username field label
  ///
  /// In ru, this message translates to:
  /// **'Username'**
  String get usernameLabel;

  /// Username field placeholder
  ///
  /// In ru, this message translates to:
  /// **'username'**
  String get usernameHint;

  /// Validation error for an invalid username
  ///
  /// In ru, this message translates to:
  /// **'Латиница, цифры, «_» и «.», минимум 3 символа'**
  String get usernameInvalid;

  /// Caption under the username field
  ///
  /// In ru, this message translates to:
  /// **'По username вас смогут найти друзья.'**
  String get usernameHelp;

  /// Title of the avatar picker bottom sheet
  ///
  /// In ru, this message translates to:
  /// **'Фото профиля'**
  String get photoSheetTitle;

  /// Label of a mock avatar option
  ///
  /// In ru, this message translates to:
  /// **'Аватар {n}'**
  String avatarOption(int n);

  /// Option that clears the avatar
  ///
  /// In ru, this message translates to:
  /// **'Убрать фото'**
  String get photoRemove;

  /// Button that opens the avatar picker
  ///
  /// In ru, this message translates to:
  /// **'Изменить фото'**
  String get photoChange;

  /// Error when the profile row is missing
  ///
  /// In ru, this message translates to:
  /// **'Профиль не найден.'**
  String get profileNotFound;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
