import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/sync/sync_engine.dart';
import '../../../auth/domain/user.dart';
import '../../data/profile_repository.dart';

/// Контроллер профиля текущего пользователя.
///
/// Подписан на Drift stream — локальная мутация и результат sync
/// обновляют UI автоматически. Сети здесь нет: push/pull делает
/// SyncEngine через outbox.
class ProfileController extends StreamNotifier<User?> {
  @override
  Stream<User?> build() {
    return ref.watch(profileRepositoryProvider).watchProfile();
  }

  /// Pull-to-refresh / invalidate экрана: запросить sync.
  Future<void> refresh() => ref.read(syncEngineProvider).requestSync();
}

/// Провайдер профиля — реактивный, Drift-backed.
final profileControllerProvider =
    StreamNotifierProvider<ProfileController, User?>(ProfileController.new);
