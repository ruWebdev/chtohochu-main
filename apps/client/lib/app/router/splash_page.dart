import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Минимальный экран загрузки.
///
/// Показывается во время определения состояния сессии, чтобы избежать
/// flash неправильного экрана. Не содержит брендинга — просто индикатор.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.background,
      body: Center(child: CircularProgressIndicator(color: colors.primary)),
    );
  }
}
