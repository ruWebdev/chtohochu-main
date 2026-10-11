import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../l10n/l10n.dart';
import '../data/share_api.dart';

/// Защита от параллельных share-запросов — двойной тап по
/// «Поделиться» не должен порождать второй POST.
class ShareInFlight extends Notifier<bool> {
  @override
  bool build() => false;

  set busy(bool value) => state = value;
}

// Без autoDispose: guard читается только через `ref.read`
// внутри действия — у autoDispose-провайдера без слушателей
// состояние бы сбрасывалось между вызовами.
final shareInFlightProvider = NotifierProvider<ShareInFlight, bool>(
  ShareInFlight.new,
);

/// Общий flow «Поделиться» для Wish/WishList:
/// create → URL → системный Share sheet.
///
/// Online-only: при ошибке сети/API — `errorGeneric`, без
/// локальных записей и фиктивных ссылок. Повторный вызов,
/// пока предыдущий не завершён, игнорируется.
Future<void> shareEntity(
  BuildContext context,
  WidgetRef ref,
  Future<ShareLink> Function(ShareApi api) create,
) async {
  final inFlight = ref.read(shareInFlightProvider.notifier);
  if (ref.read(shareInFlightProvider)) return;
  inFlight.busy = true;
  try {
    final link = await create(ref.read(shareApiProvider));
    if (!context.mounted) return;
    await SharePlus.instance.share(ShareParams(text: link.url));
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.errorGeneric)));
  } finally {
    inFlight.busy = false;
  }
}
