import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/wish_repository.dart';
import '../../domain/wish.dart';

/// Состояние формы желания (создание / редактирование).
sealed class WishFormState {
  const WishFormState();
}

/// Форма готова к вводу.
class WishFormIdle extends WishFormState {
  const WishFormIdle({this.error});

  /// Типизированная ошибка — текст выбирает UI через `wishErrorMessage`.
  final WishError? error;
}

/// Выполняется сохранение.
class WishFormLoading extends WishFormState {
  const WishFormLoading();
}

/// Желание успешно сохранено.
class WishFormSuccess extends WishFormState {
  const WishFormSuccess(this.wish);
  final Wish wish;
}

/// Контроллер формы желания.
///
/// Один контроллер и для создания, и для редактирования — различие
/// только в наличии [existing]. Управляет сохранением и защищает
/// от двойного сабмита (повторное нажатие во время загрузки
/// игнорируется).
class WishFormController extends Notifier<WishFormState> {
  @override
  WishFormState build() => const WishFormIdle();

  /// Сохранить желание.
  ///
  /// Если [existing] задан — обновляет существующее желание,
  /// иначе создаёт новое. Возвращает сохранённый [Wish] при успехе,
  /// `null` при ошибке или повторном вызове во время загрузки.
  Future<Wish?> save({
    required String title,
    String? description,
    int? price,
    String? link,
    String? imageUrl,
    List<String> additionalImagePaths = const [],
    Wish? existing,
  }) async {
    if (state is WishFormLoading) return null;
    state = const WishFormLoading();
    try {
      final repo = ref.read(wishRepositoryProvider);
      final Wish wish;
      if (existing == null) {
        wish = await repo.createWish(
          title: title,
          description: description,
          price: price,
          link: link,
          imageUrl: imageUrl,
          additionalImagePaths: additionalImagePaths,
        );
      } else {
        // Список обновится сам через Drift stream — ручной
        // apply* в контроллере списка больше не нужен.
        wish = await repo.updateWish(
          Wish(
            id: existing.id,
            title: title,
            description: description,
            price: price,
            link: link,
            imageUrl: imageUrl,
            createdAt: existing.createdAt,
          ),
        );
      }
      state = WishFormSuccess(wish);
      return wish;
    } on WishError catch (e) {
      state = WishFormIdle(error: e);
      return null;
    } catch (_) {
      state = const WishFormIdle(error: UnknownWishError());
      return null;
    }
  }

  /// Сбросить состояние формы.
  void reset() => state = const WishFormIdle();
}

/// Провайдер контроллера формы желания.
final wishFormControllerProvider =
    NotifierProvider<WishFormController, WishFormState>(WishFormController.new);
