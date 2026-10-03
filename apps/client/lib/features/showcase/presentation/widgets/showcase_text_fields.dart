import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../shared/ui/ui.dart';
import 'showcase_section.dart';

/// Секция: поля ввода.
class ShowcaseTextFields extends StatelessWidget {
  const ShowcaseTextFields({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ShowcaseSubLabel('Обычное'),
        const AppTextField(hint: 'Что ты хочешь?'),
        const ShowcaseSubLabel('С label'),
        const AppTextField(label: 'Название', hint: 'Например, наушники'),
        const ShowcaseSubLabel('С leading иконкой'),
        const AppTextField(
          hint: 'Поиск',
          leading: Icon(PhosphorIconsRegular.magnifyingGlass),
        ),
        const ShowcaseSubLabel('С trailing иконкой'),
        const AppTextField(
          hint: 'Ссылка на товар',
          trailing: Icon(PhosphorIconsRegular.arrowRight),
        ),
        const ShowcaseSubLabel('Password'),
        const AppTextField(
          hint: 'Пароль',
          obscureText: true,
          leading: Icon(PhosphorIconsRegular.lock),
        ),
        const ShowcaseSubLabel('Error'),
        const AppTextField(
          hint: 'Email',
          errorText: 'Введите корректный email',
        ),
        const ShowcaseSubLabel('Disabled'),
        const AppTextField(hint: 'Недоступное поле', enabled: false),
        const ShowcaseSubLabel('Multiline'),
        const AppTextField(
          hint: 'Комментарий к желанию…',
          maxLines: 3,
          minLines: 2,
        ),
      ],
    );
  }
}
