import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_router.dart';
import 'routes.dart';

/// Обработчик входящих share-ссылок `https://chtohochu.ru/s/{token}`.
///
/// Подписывается на `app_links` (cold start — `getInitialLink`,
/// warm/background — `uriLinkStream`) и ведёт на публичный route
/// `/s/:token`. Auth-gate роутера эту ветку пропускает, поэтому
/// ссылка открывается и без сессии, и пока сессия ещё грузится.
///
/// Дедупликация: initial URI и stream-событие одного открытия
/// приходят дважды — повторный одинаковый URI в коротком окне
/// игнорируется, чтобы не плодить навигации.
class ShareDeepLinkHandler {
  ShareDeepLinkHandler({required this._router, this._links});

  final GoRouter _router;
  AppLinks? _links;
  StreamSubscription<Uri>? _sub;
  bool _started = false;

  Uri? _lastUri;
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// Hosts, с которых принимаем share-ссылки: prod-домены и
  /// локальный dev-домен.
  static const _shareHosts = {
    'chtohochu.ru',
    'www.chtohochu.ru',
    'www.chtohochu.test',
  };

  /// Запустить обработку (idempotent).
  void start() {
    if (_started) return;
    _started = true;
    final links = _links ??= AppLinks();
    try {
      _sub = links.uriLinkStream.listen(
        handleUri,
        // Отсутствующий plugin channel (тесты/web) — не ошибка.
        onError: (_) {},
      );
      links.getInitialLink().then((uri) {
        if (uri != null) handleUri(uri);
      }, onError: (_) => null);
    } catch (_) {
      // Платформа без app_links — deep links просто не приходят.
    }
  }

  /// Обработать входящий URI: распознать `/s/{token}` на share-хосте
  /// и перейти на публичный viewer. Прочие URI игнорируются.
  ///
  /// Публичный метод — тесты и прямые вызовы не требуют плагина.
  void handleUri(Uri uri) {
    final segments = uri.pathSegments;
    if (segments.length != 2 || segments[0] != 's' || segments[1].isEmpty) {
      return;
    }
    if (!_shareHosts.contains(uri.host)) return;

    // Тот же URI подряд (initial + stream одного события) — пропускаем.
    final now = DateTime.now();
    if (uri == _lastUri &&
        now.difference(_lastAt) < const Duration(seconds: 2)) {
      return;
    }
    _lastUri = uri;
    _lastAt = now;

    _router.go(AppRoutes.share(segments[1]));
  }

  void dispose() {
    _sub?.cancel();
  }
}

/// Живёт на всю сессию приложения; `start()` вызывается в initState
/// корневого виджета.
final shareDeepLinkHandlerProvider = Provider<ShareDeepLinkHandler>((ref) {
  final handler = ShareDeepLinkHandler(router: ref.watch(goRouterProvider));
  ref.onDispose(handler.dispose);
  return handler;
});
