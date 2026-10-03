import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

/// Провайдер локальной базы Drift.
///
/// Создаётся лениво, живёт всю сессию (`keepAlive`). В тестах
/// переопределяется на `AppDatabase.forTesting(NativeDatabase.memory())`.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
