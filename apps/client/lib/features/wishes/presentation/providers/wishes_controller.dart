import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/sync/sync_engine.dart';
import '../../data/wish_repository.dart';
import '../../domain/wish.dart';

/// Контроллер списка желаний.
///
/// Подписан на Drift stream репозитория — локальные мутации и
/// результат sync обновляют UI автоматически, без ручного
/// управления списком в памяти.
class WishesController extends StreamNotifier<List<Wish>> {
  @override
  Stream<List<Wish>> build() {
    return ref.watch(wishRepositoryProvider).watchWishes();
  }

  /// Pull-to-refresh: запросить синхронизацию (push outbox +
  /// pull snapshot). UI продолжает читать Drift — сетевой сбой
  /// не превращает экран в error state.
  Future<void> refresh() => ref.read(syncEngineProvider).requestSync();

  /// Удалить желание (локально + outbox; UI обновится из stream).
  Future<void> deleteWish(String id) =>
      ref.read(wishRepositoryProvider).deleteWish(id);
}

/// Провайдер списка желаний.
final wishesControllerProvider =
    StreamNotifierProvider<WishesController, List<Wish>>(WishesController.new);

/// Желание по id из загруженного списка.
///
/// Используется экраном деталей — автоматически отражает изменения
/// после редактирования. `null`, пока список грузится или желание
/// не найдено.
final wishByIdProvider = Provider.family<Wish?, String>((ref, id) {
  final wishes = ref.watch(wishesControllerProvider).value;
  if (wishes == null) return null;
  for (final w in wishes) {
    if (w.id == id) return w;
  }
  return null;
});
