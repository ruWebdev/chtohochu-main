import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../l10n/l10n.dart';
import '../buttons/app_icon_button.dart';
import 'app_image.dart';

/// Полноэкранный просмотр изображения.
///
/// Открывается модально поверх текущего экрана: чёрный фон,
/// пинч-зум через [InteractiveViewer], стандартная белая круглая
/// кнопка «Назад» слева вверху и системный жест/кнопка Back.
Future<void> showAppImageViewer(
  BuildContext context, {
  required String src,
  String? semanticLabel,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) =>
          _FullscreenImageViewer(src: src, semanticLabel: semanticLabel),
    ),
  );
}

class _FullscreenImageViewer extends StatelessWidget {
  const _FullscreenImageViewer({required this.src, this.semanticLabel});

  final String src;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              maxScale: 5,
              child: Center(
                child: AppImage(
                  src: src,
                  fit: BoxFit.contain,
                  semanticLabel: semanticLabel,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.topLeft,
                child: AppIconButton(
                  icon: const Icon(PhosphorIconsRegular.arrowLeft),
                  variant: AppIconButtonVariant.subtle,
                  semanticLabel: context.l10n.back,
                  tooltip: context.l10n.back,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
