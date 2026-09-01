import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

/// Точка входа в приложение.
void main() {
  runApp(const ProviderScope(child: ChtoHochuApp()));
}
