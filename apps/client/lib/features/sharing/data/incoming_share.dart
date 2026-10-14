import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:listen_sharing_intent/listen_sharing_intent.dart';

import '../../../app/router/app_router.dart';
import '../../../app/router/routes.dart';
import '../../session/presentation/providers/app_session_controller.dart';
import '../../wishes/domain/wish_draft.dart';

/// Извлечение URL из share-текста.
///
/// Маркетплейсы шарят «Название https://… купить» — берём первый
/// http(s)-URL и обрезаем хвостовую пунктуацию.
abstract final class SharedTextParser {
  static final _urlRe = RegExp(r'https?://[^\s]+');

  static String? extractUrl(String text) {
    final raw = _urlRe.firstMatch(text)?.group(0);
    if (raw == null) return null;
    return raw.replaceAll(RegExp(r'[.,;!?\)\]]+$'), '');
  }
}

/// Дедупликатор share-событий: один intent может прийти дважды
/// (initial + stream одного жеста).
class ShareDeduper {
  String? _last;
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// `true` — событие дубликат, игнорировать.
  bool isDuplicate(
    String url,
    DateTime now, {
    Duration window = const Duration(seconds: 3),
  }) {
    if (url == _last && now.difference(_lastAt) < window) return true;
    _last = url;
    _lastAt = now;
    return false;
  }
}

/// Ожидающая доставки share-ссылка (null — нет).
class PendingShare extends Notifier<String?> {
  @override
  String? build() => null;

  set value(String? v) => state = v;
}

final pendingShareProvider = NotifierProvider<PendingShare, String?>(
  PendingShare.new,
);

/// Уведомление о новой ссылке, полученной пока открыта форма
/// `/wishes/new`: URL не применяется молча — UI показывает
/// подтверждение.
class ShareWhileFormOpen extends Notifier<String?> {
  @override
  String? build() => null;

  set value(String? v) => state = v;
}

final shareWhileFormOpenProvider =
    NotifierProvider<ShareWhileFormOpen, String?>(ShareWhileFormOpen.new);

/// Запрос на открытие импорта в `AddWishSheet`.
///
/// AppShell слушает провайдер и открывает sheet поверх текущего UI —
/// открытый ранее sheet с пользовательским вводом остаётся в стеке
/// и не затирается.
class ImportRequest extends Notifier<WishDraft?> {
  @override
  WishDraft? build() => null;

  set value(WishDraft? v) => state = v;
}

final importRequestProvider = NotifierProvider<ImportRequest, WishDraft?>(
  ImportRequest.new,
);

/// Обработчик входящего шеринга (`ACTION_SEND text/plain`).
///
/// Cold start — `getInitialMedia`, warm — `getMediaStream`. Извлекает
/// URL и запрашивает импорт в `AddWishSheet` через [WishDraft] как
/// только сессия готова (`AppSessionReady`); до этого событие ждёт в
/// [pendingShareProvider] — не теряется при auth/onboarding.
class IncomingShareHandler {
  IncomingShareHandler({required this.onUrl});

  /// Колбэк доставки извлечённого URL.
  final void Function(String url) onUrl;

  StreamSubscription<List<SharedMediaFile>>? _sub;
  final _deduper = ShareDeduper();
  bool _started = false;

  /// Запустить приём (idempotent).
  void start() {
    if (_started) return;
    _started = true;
    try {
      _sub = ReceiveSharingIntent.instance.getMediaStream().listen(
        _onMedia,
        onError: (_) {},
      );
      ReceiveSharingIntent.instance
          .getInitialMedia()
          .then((media) {
            _onMedia(media);
            ReceiveSharingIntent.instance.reset();
          })
          .onError((_, _) {});
    } catch (_) {
      // Платформа без плагина (тесты, desktop) — share не приходит.
    }
  }

  void _onMedia(List<SharedMediaFile> media) {
    for (final m in media) {
      if (m.type != SharedMediaType.text && m.type != SharedMediaType.url) {
        continue;
      }
      final url = SharedTextParser.extractUrl(m.path);
      if (url == null) continue;
      if (_deduper.isDuplicate(url, DateTime.now())) continue;
      onUrl(url);
    }
  }

  void dispose() {
    _sub?.cancel();
  }
}

/// Провайдер обработчика: маршрутизирует URL в форму желания.
///
/// Доставка откладывается до `AppSessionReady` — redirect-логика
/// роутера раньше этого момента отправила бы на splash/auth
/// и событие потерялось бы. Если форма `/wishes/new` уже открыта —
/// URL публикуется в [shareWhileFormOpenProvider] для подтверждения.
final incomingShareHandlerProvider = Provider<IncomingShareHandler>((ref) {
  void deliverPending() {
    final url = ref.read(pendingShareProvider);
    if (url == null) return;
    final session = ref.read(appSessionControllerProvider).value;
    if (session is! AppSessionReady) return;

    final router = ref.read(goRouterProvider);
    final loc = router.routerDelegate.currentConfiguration.uri.path;
    ref.read(pendingShareProvider.notifier).value = null;
    if (loc == AppRoutes.newWish) {
      // Полная форма открыта — не затираем ввод молча: публикуем
      // уведомление; ссылка живёт в нём до выбора пользователя.
      ref.read(shareWhileFormOpenProvider.notifier).value = url;
      return;
    }
    // Иначе — импорт в AddWishSheet: открывается поверх текущего
    // экрана (и поверх уже открытого sheet с вводом — он остаётся
    // в стеке и не теряется).
    ref.read(importRequestProvider.notifier).value = WishDraft(link: url);
  }

  // Доставка при готовности сессии (cold start, post-auth).
  ref.listen<dynamic>(appSessionControllerProvider, (_, _) => deliverPending());

  final handler = IncomingShareHandler(
    onUrl: (url) {
      if (ref.read(pendingShareProvider) == url) return;
      ref.read(pendingShareProvider.notifier).value = url;
      deliverPending();
    },
  );
  ref.onDispose(handler.dispose);
  return handler;
});
