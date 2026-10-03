import 'package:chtohochu/l10n/l10n.dart';

/// «1 список» / «2 списка» / «5 списков».
String listsCountLabel(AppLocalizations l10n, int count) =>
    l10n.listsCount(count);

/// «1 позиция» / «3 позиции» / «5 позиций».
String itemsCountLabel(AppLocalizations l10n, int count) =>
    l10n.itemsCount(count);
