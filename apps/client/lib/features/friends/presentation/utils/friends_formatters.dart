import 'package:chtohochu/l10n/l10n.dart';

/// «1 друг» / «3 друга» / «5 друзей».
String friendsCountLabel(AppLocalizations l10n, int count) =>
    l10n.friendsCount(count);

/// Отображаемое имя: пустое имя → локализованный fallback «Без имени».
///
/// В data-слое fallback не хранится — БД/кэш держат фактическое
/// значение (пустую строку), presentation решает, что показать.
String friendDisplayName(AppLocalizations l10n, String name) =>
    name.trim().isEmpty ? l10n.noName : name;
