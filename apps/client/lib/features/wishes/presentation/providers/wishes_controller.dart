import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/sync/sync_engine.dart';
import '../../data/wish_repository.dart';
import '../../domain/wish.dart';
import '../../domain/wish_image.dart';
import '../../domain/wish_list.dart';

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

  /// Переместить желание в список (`null` — убрать из списков).
  /// Membership — часть серверной модели: мутация идёт обычным
  /// wish update-op через outbox.
  Future<void> assignWishToList(String wishId, String? listId) =>
      ref.read(wishRepositoryProvider).assignWishToList(wishId, listId);
}

/// Провайдер списка желаний.
final wishesControllerProvider =
    StreamNotifierProvider<WishesController, List<Wish>>(WishesController.new);

/// Списки желаний текущего пользователя.
///
/// Реактивный Drift-стрим репозитория — создание списка и
/// изменение членства желаний обновляют UI автоматически.
final wishListsProvider = StreamProvider<List<WishList>>(
  (ref) => ref.watch(wishRepositoryProvider).watchWishLists(),
);

/// Список желаний по id — из общего стрима `wishListsProvider`
/// (включает вычисленный `wishCount`).
final wishListByIdProvider = Provider.family<WishList?, String>((ref, id) {
  final lists = ref.watch(wishListsProvider).value;
  if (lists == null) return null;
  for (final l in lists) {
    if (l.id == id) return l;
  }
  return null;
});

/// Желания конкретного списка — реактивный Drift-стрим.
/// Изменение `Wish.listId` (assign/разгруппировка/pull) меняет
/// содержимое экрана автоматически.
final wishListWishesProvider = StreamProvider.family<List<Wish>, String>((
  ref,
  listId,
) {
  return ref.watch(wishRepositoryProvider).watchWishesInList(listId);
});

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

/// Дополнительные изображения желания (primary — `Wish.imageUrl`).
///
/// Используется экраном деталей — реактивный Drift-стрим,
/// обновляется вместе с локальными мутациями.
final wishImagesProvider = StreamProvider.family<List<WishImage>, String>((
  ref,
  wishId,
) {
  return ref.watch(wishRepositoryProvider).watchWishImages(wishId);
});
