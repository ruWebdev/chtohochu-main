import 'package:flutter/material.dart';

/// Минимальный экран-заставка.
///
/// Бизнес-логика отсутствует. Будет заменён логикой инициализации
/// в последующих фазах.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
