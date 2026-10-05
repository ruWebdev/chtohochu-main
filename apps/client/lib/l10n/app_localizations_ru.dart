// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appName => 'ЧтоХочу';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Отмена';

  @override
  String get close => 'Закрыть';

  @override
  String get back => 'Назад';

  @override
  String get more => 'Ещё';

  @override
  String get notificationsTitle => 'Оповещения';

  @override
  String get notificationsEmptyTitle => 'Пока нет оповещений';

  @override
  String get notificationsEmptyDescription =>
      'Здесь будут появляться оповещения.';

  @override
  String get save => 'Сохранить';

  @override
  String get saveChanges => 'Сохранить изменения';

  @override
  String get delete => 'Удалить';

  @override
  String get edit => 'Редактировать';

  @override
  String get add => 'Добавить';

  @override
  String get refresh => 'Обновить';

  @override
  String get skip => 'Пропустить';

  @override
  String get orSeparator => 'или';

  @override
  String get tryAgain => 'Попробуйте ещё раз.';

  @override
  String get loadFailed => 'Не удалось загрузить';

  @override
  String get pullToRefresh => 'Потяните вниз, чтобы обновить.';

  @override
  String get syncNotSynced => 'не синхронизировано';

  @override
  String get noName => 'Без имени';

  @override
  String get urlHint => 'https://…';

  @override
  String get errorSaveFailed => 'Не удалось сохранить. Проверьте интернет.';

  @override
  String get errorNotAuthenticated => 'Пользователь не авторизован.';

  @override
  String get errorValidation => 'Ошибка валидации.';

  @override
  String get errorGeneric => 'Произошла ошибка. Попробуйте ещё раз.';

  @override
  String get navWishes => 'Что хочу';

  @override
  String get navShopping => 'Покупки';

  @override
  String get navFriends => 'Друзья';

  @override
  String get navProfile => 'Профиль';

  @override
  String get authTagline => 'Твоё пространство желаний';

  @override
  String get authSubtitleLogin => 'Войдите, чтобы продолжить';

  @override
  String get authSubtitleRegister => 'Создайте аккаунт за минуту';

  @override
  String get authTabLogin => 'Вход';

  @override
  String get authTabRegister => 'Регистрация';

  @override
  String get authNameLabel => 'Имя (необязательно)';

  @override
  String get authNameHint => 'Как вас зовут';

  @override
  String get authNameSemantic => 'Имя';

  @override
  String get emailLabel => 'Email';

  @override
  String get emailSemantic => 'Адрес электронной почты';

  @override
  String get emailHint => 'you@example.com';

  @override
  String get passwordLabel => 'Пароль';

  @override
  String get passwordHint => 'Минимум 6 символов';

  @override
  String get passwordSemantic => 'Пароль';

  @override
  String get showPassword => 'Показать пароль';

  @override
  String get hidePassword => 'Скрыть пароль';

  @override
  String get authLoginButton => 'Войти';

  @override
  String get authRegisterButton => 'Создать аккаунт';

  @override
  String get authVkButton => 'Войти через VK';

  @override
  String get authYandexButton => 'Войти через Яндекс';

  @override
  String get emailInvalid => 'Введите корректный email';

  @override
  String get passwordTooShort => 'Пароль не короче 8 символов';

  @override
  String get authInvalidCredentials => 'Неверный email или пароль';

  @override
  String get authEmailTaken => 'Аккаунт с таким email уже существует';

  @override
  String get authNetwork => 'Проверьте подключение к интернету';

  @override
  String get authGeneric => 'Произошла ошибка. Попробуйте ещё раз.';

  @override
  String get authVkFailed => 'Не удалось войти через VK.';

  @override
  String get authYandexFailed => 'Не удалось войти через Яндекс.';

  @override
  String get authVkUnavailable => 'Вход через VK скоро будет доступен.';

  @override
  String get authYandexUnavailable => 'Вход через Яндекс скоро будет доступен.';

  @override
  String get oauthUnavailableTitle => 'Вход через соцсети скоро будет доступен';

  @override
  String get onboardingSkip => 'Пропустить';

  @override
  String get onboardingNext => 'Далее';

  @override
  String get onboardingStart => 'Начать';

  @override
  String get onboardingSlide1Title =>
      'ЧтоХочу — место, куда ты складываешь то, чего хочешь';

  @override
  String get onboardingSlide1Description =>
      'Записывайте свои желания в одном месте, чтобы ничего не потерялось.';

  @override
  String get onboardingSlide2Title => 'Чтобы самому не забыть';

  @override
  String get onboardingSlide2Description =>
      'Добавляйте идеи подарков, вещи и мечты — они всегда будут под рукой.';

  @override
  String get onboardingSlide3Title =>
      'И чтобы близким было проще понять, что подарить';

  @override
  String get onboardingSlide3Description =>
      'Поделитесь списком — и получите именно то, чего вы действительно хотите.';

  @override
  String get wishesTitle => 'Что хочу';

  @override
  String wishesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count желаний',
      many: '$count желаний',
      few: '$count желания',
      one: '$count желание',
    );
    return '$_temp0';
  }

  @override
  String get wishAdd => 'Добавить желание';

  @override
  String get wishAddFirst => 'Добавить первое желание';

  @override
  String get wishesEmptyTitle => 'Что ты хочешь?';

  @override
  String get wishesEmptyDescription =>
      'Запиши, чего хочешь, — чтобы не забыть и чтобы близким было проще выбрать подарок.';

  @override
  String get friendWishesEmptyTitle => 'Пока нет желаний';

  @override
  String get wishNotFound => 'Желание не найдено';

  @override
  String get wishNotFoundHint => 'Возможно, оно было удалено.';

  @override
  String get wishNotFoundByOwner => 'Возможно, оно было удалено владельцем.';

  @override
  String get backToList => 'К списку';

  @override
  String get wishEditTitle => 'Редактировать желание';

  @override
  String get wishEditSemantic => 'Редактировать желание';

  @override
  String get wishNewTitle => 'Новое желание';

  @override
  String get wishTitleLabel => 'Что вы хотите?';

  @override
  String get wishTitleHint => 'Например: наушники Sony WH-1000XM6';

  @override
  String get wishTitleSemantic => 'Название желания';

  @override
  String get wishPriceLabel => 'Цена, ₽ (необязательно)';

  @override
  String get wishPriceHint => '12 990';

  @override
  String get wishPriceSemantic => 'Примерная цена в рублях';

  @override
  String get wishLinkLabel => 'Ссылка на товар (необязательно)';

  @override
  String get wishLinkSemantic => 'Ссылка на товар';

  @override
  String get wishImageLabel => 'Ссылка на изображение (необязательно)';

  @override
  String get wishImageSemantic => 'Ссылка на изображение';

  @override
  String get wishNoteLabel => 'Заметка (необязательно)';

  @override
  String get wishNoteHint => 'Размер, цвет, детали…';

  @override
  String get wishNoteSemantic => 'Заметка о желании';

  @override
  String get wishTitleRequired => 'Введите название желания';

  @override
  String wishTitleTooLong(int max) {
    return 'Слишком длинное название (макс. $max символов)';
  }

  @override
  String get wishPriceInvalid => 'Введите цену числом';

  @override
  String get wishSave => 'Сохранить желание';

  @override
  String get wishDeleteTitle => 'Удалить желание?';

  @override
  String wishDeleteMessage(String title) {
    return '«$title» будет удалено без возможности восстановления.';
  }

  @override
  String get wishDeleteSemantic => 'Удалить желание';

  @override
  String get linkCopied => 'Ссылка скопирована';

  @override
  String get noteSection => 'Заметка';

  @override
  String wishAddedOn(String date) {
    return 'Добавлено $date';
  }

  @override
  String get wishSaveFailed => 'Не удалось сохранить желание.';

  @override
  String get wishDeleteFailed => 'Не удалось удалить желание.';

  @override
  String get wishNotFoundError => 'Желание не найдено.';

  @override
  String get firstWishTitle => 'Создай своё первое желание';

  @override
  String get firstWishDescription =>
      'Запишите то, чего вы хотите — чтобы не забыть самим и помочь близким выбрать правильный подарок.';

  @override
  String get wishQuickHint => 'Что хочешь?';

  @override
  String get wishUrlAction => 'URL';

  @override
  String get wishUrlActionSemantic => 'Добавить ссылку';

  @override
  String get wishUrlLabel => 'Ссылка';

  @override
  String get wishUrlInvalid => 'Некорректная ссылка';

  @override
  String get wishCameraAction => 'Камера';

  @override
  String get wishCameraActionSemantic => 'Сфотографировать желание';

  @override
  String get wishGalleryAction => 'Галерея';

  @override
  String get wishGalleryActionSemantic => 'Выбрать фото из галереи';

  @override
  String get wishPhotoRemove => 'Удалить фото';

  @override
  String get wishPhotoError => 'Не удалось получить фото.';

  @override
  String get wishPhotoFallbackTitle => 'Фотография';

  @override
  String get wishDiscardTitle => 'Закрыть без сохранения?';

  @override
  String get wishDiscardMessage => 'Введённые данные будут потеряны.';

  @override
  String get shoppingTitle => 'Покупки';

  @override
  String listsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count списков',
      many: '$count списков',
      few: '$count списка',
      one: '$count список',
    );
    return '$_temp0';
  }

  @override
  String itemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count позиций',
      many: '$count позиций',
      few: '$count позиции',
      one: '$count позиция',
    );
    return '$_temp0';
  }

  @override
  String get listAdd => 'Создать список покупок';

  @override
  String get listsEmptyTitle => 'Пока нет списков';

  @override
  String get listsEmptyDescription =>
      'Создавайте списки покупок — продукты на неделю, в поездку, для дома — и отмечайте купленное.';

  @override
  String get listCreate => 'Создать список';

  @override
  String get listRename => 'Переименовать список';

  @override
  String get listNewTitle => 'Новый список';

  @override
  String get listTitleLabel => 'Название списка';

  @override
  String get listTitleHint => 'Например: продукты на неделю';

  @override
  String get listTitleRequired => 'Введите название списка';

  @override
  String listTitleTooLong(int max) {
    return 'Слишком длинное название (макс. $max символов)';
  }

  @override
  String get listDeleteTitle => 'Удалить список?';

  @override
  String listDeleteMessage(String title) {
    return '«$title» и все его позиции будут удалены без возможности восстановления.';
  }

  @override
  String get listDeleteSemantic => 'Удалить список';

  @override
  String get listRenameTooltip => 'Переименовать';

  @override
  String get listNotFound => 'Список не найден';

  @override
  String get listNotFoundHint => 'Возможно, он был удалён.';

  @override
  String get backToLists => 'К спискам';

  @override
  String get listAllDone => 'Всё куплено';

  @override
  String get listEmpty => 'Список пуст';

  @override
  String get listEmptyHint => 'Пока пусто';

  @override
  String listProgress(int checked, int total) {
    return '$checked из $total куплено';
  }

  @override
  String get listEmptyItems => 'В списке пока ничего нет';

  @override
  String get itemAdd => 'Добавить товар';

  @override
  String get itemTitleHint => 'Название товара';

  @override
  String get itemAddCloseSemantic => 'Закрыть поле добавления';

  @override
  String get itemSheetTitle => 'Позиция';

  @override
  String get itemNameLabel => 'Название';

  @override
  String get itemQuantityLabel => 'Количество';

  @override
  String get listSaveFailed => 'Не удалось сохранить список.';

  @override
  String get listNotFoundError => 'Список не найден.';

  @override
  String get itemNotFoundError => 'Позиция не найдена.';

  @override
  String get friendsTitle => 'Друзья';

  @override
  String friendsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count друзей',
      many: '$count друзей',
      few: '$count друга',
      one: '$count друг',
    );
    return '$_temp0';
  }

  @override
  String get friendAdd => 'Добавить друга';

  @override
  String get friendsEmptyTitle => 'Пока нет друзей';

  @override
  String get friendsEmptyDescription =>
      'Добавьте близких, чтобы видеть их желания и проще выбирать подарки.';

  @override
  String get friendSearchHint => 'Имя или @username';

  @override
  String get friendSearchEmptyTitle => 'Найдите друга';

  @override
  String get friendSearchEmptyDescription =>
      'Введите имя или @username — человек появится в результатах поиска.';

  @override
  String get friendSearchFailed => 'Не удалось выполнить поиск';

  @override
  String get friendSearchNoResults => 'Никого не нашли';

  @override
  String friendSearchNoResultsHint(String query) {
    return 'По запросу «$query» нет пользователей. Проверьте имя или username.';
  }

  @override
  String get friendAdded => 'Добавлен';

  @override
  String get friendAlready => 'В друзьях';

  @override
  String friendAddedSnack(String name) {
    return '$name добавлен(а) в друзья';
  }

  @override
  String get friendAddFailed =>
      'Не удалось добавить друга. Попробуйте ещё раз.';

  @override
  String get friendRemoveFailed => 'Не удалось удалить друга.';

  @override
  String get friendRemoveTitle => 'Удалить из друзей?';

  @override
  String friendRemoveMessage(String name) {
    return '$name исчезнет из вашего списка друзей. Вы сможете добавить его снова через поиск.';
  }

  @override
  String get friendRemove => 'Удалить из друзей';

  @override
  String get friendNotFound => 'Друг не найден';

  @override
  String get friendNotFoundHint => 'Возможно, он был удалён из списка.';

  @override
  String get backToFriends => 'К списку друзей';

  @override
  String get backToFriend => 'К профилю друга';

  @override
  String get wishesSection => 'Желания';

  @override
  String wishesSectionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count желаний',
      many: '$count желаний',
      few: '$count желания',
      one: '$count желание',
    );
    return 'Желания · $_temp0';
  }

  @override
  String friendNoWishes(String name) {
    return '$name ещё не добавил(а) желания, которые вам видны.';
  }

  @override
  String get friendUserNotFound => 'Пользователь не найден.';

  @override
  String get friendCannotAddSelf => 'Нельзя добавить себя.';

  @override
  String get profileTitle => 'Профиль';

  @override
  String get profileEdit => 'Редактировать профиль';

  @override
  String get settingsSection => 'Настройки';

  @override
  String get accountSection => 'Аккаунт';

  @override
  String get aboutSection => 'О приложении';

  @override
  String get appearance => 'Внешний вид';

  @override
  String get themeSystem => 'Системная';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get logout => 'Выйти';

  @override
  String get logoutTitle => 'Выйти из аккаунта?';

  @override
  String get logoutMessage => 'Вы сможете войти снова позже.';

  @override
  String get logoutPendingTitle => 'Несохранённые изменения';

  @override
  String logoutPendingMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count изменений ещё не отправлено на сервер.',
      many: '$count изменений ещё не отправлено на сервер.',
      few: '$count изменения ещё не отправлены на сервер.',
      one: '$count изменение ещё не отправлено на сервер.',
    );
    return '$_temp0 Если выйти сейчас, они будут удалены.';
  }

  @override
  String get logoutPendingConfirm => 'Удалить и выйти';

  @override
  String versionLabel(String version) {
    return 'Версия $version';
  }

  @override
  String get nameLabel => 'Имя';

  @override
  String get nameHintProfile => 'Как вас видят друзья';

  @override
  String get nameRequired => 'Укажите имя';

  @override
  String get usernameLabel => 'Username';

  @override
  String get usernameHint => 'username';

  @override
  String get usernameInvalid => 'Латиница, цифры, «_» и «.», минимум 3 символа';

  @override
  String get usernameHelp => 'По username вас смогут найти друзья.';

  @override
  String get photoSheetTitle => 'Фото профиля';

  @override
  String avatarOption(int n) {
    return 'Аватар $n';
  }

  @override
  String get photoRemove => 'Убрать фото';

  @override
  String get photoChange => 'Изменить фото';

  @override
  String get profileNotFound => 'Профиль не найден.';
}
