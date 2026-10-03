/// Общие форматтеры отображения.
///
/// Числа и даты форматируются через `intl` — чтобы будущие локали
/// получали корректные представления. Локальные данные `intl`
/// инициализируются один раз при старте (`initializeDateFormatting`
/// в `main.dart`), сеть не требуется.
library;

import 'package:intl/intl.dart';

/// «12 990 ₽» — цена в рублях с разделением тысяч.
///
/// `NumberFormat` для `ru` использует неразрывный пробел как
/// разделитель групп и перед символом валюты; заменяем на обычный,
/// чтобы сохранить прежнее отображение.
String formatPrice(int rubles) {
  return NumberFormat.currency(
    locale: 'ru',
    symbol: '₽',
    decimalDigits: 0,
  ).format(rubles).replaceAll('\u00A0', ' ');
}

/// «15 сентября 2025» — дата в родительном падеже месяца.
///
/// [locale] — текущая локаль UI (например, `context.l10n.localeName`).
String formatDate(DateTime date, [String locale = 'ru']) {
  return DateFormat('d MMMM yyyy', locale).format(date);
}
