import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:chtohochu/l10n/l10n.dart';

/// Подпись режима темы для UI.
String themeModeLabel(AppLocalizations l10n, ThemeMode mode) => switch (mode) {
  ThemeMode.system => l10n.themeSystem,
  ThemeMode.light => l10n.themeLight,
  ThemeMode.dark => l10n.themeDark,
};

/// Иконка режима темы.
IconData themeModeIcon(ThemeMode mode) => switch (mode) {
  ThemeMode.system => PhosphorIconsRegular.circleHalf,
  ThemeMode.light => PhosphorIconsRegular.sun,
  ThemeMode.dark => PhosphorIconsRegular.moon,
};
