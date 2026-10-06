import 'dart:async';
import 'dart:collection';

import 'package:dart_pusher_channels/dart_pusher_channels.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/session/presentation/providers/app_session_controller.dart';
import '../config/env_config.dart';
import '../constants/api_constants.dart';
import '../network/api_client.dart';
import '../sync/sync_engine.dart';
import 'realtime_event.dart';

/// Состояние realtime-соединения для UI/диагностики.
enum RealtimeStatus { disconnected, connecting, connected, reconnecting }

/// Дедупликатор `event_id` с ограниченным размером (LRU-окно).
///
/// docs/20-backend/realtime-events.md §6: одинаковый `event_id` —
/// это повторная доставка, событие отбрасывается.
class RealtimeEventDeduper {
  RealtimeEventDeduper({this.capacity = 256});

  final int capacity;
  final LinkedHashSet<String> _seen = LinkedHashSet<String>();

  /// `true` — событие новое (и отмечено виденным); `false` — дубликат.
  bool check(String eventId) {
    if (_seen.contains(eventId)) return false;
    _seen.add(eventId);
    while (_seen.length > capacity) {
      _seen.remove(_seen.first);
    }
    return true;
  }

  void clear() => _seen.clear();
}

/// Realtime-транспорт (Laravel Reverb, pusher-протокол).
///
/// PostgreSQL — source of truth; этот клиент — только доставка событий
/// (AGENTS.md §13, docs/01-architecture/realtime.md). События после
/// дедупликации передаются в [onEvent] — дальше триггерится
/// refresh/reconcile через SyncEngine.
///
/// Жизненный цикл привязан к аккаунту через [attach]/[detach]
/// (тот же паттерн, что у SyncEngine): attach вызывается при
/// установленной сессии, detach — при logout/смене аккаунта.
class RealtimeClient {
  RealtimeClient({
    required this._dio,
    required this._env,
    this._onStatus,
    this._onEvent,
    this._onAuthFailure,
  });

  final Dio _dio;
  final EnvConfig _env;
  final void Function(RealtimeStatus status)? _onStatus;
  final void Function(RealtimeEvent event)? _onEvent;
  final void Function()? _onAuthFailure;

  String? _userId;
  PusherChannelsClient? _client;
  PrivateChannel? _userChannel;

  final RealtimeEventDeduper _deduper = RealtimeEventDeduper();

  StreamSubscription<PusherChannelsClientLifeCycleState>? _lifecycleSub;
  StreamSubscription<void>? _connectionEstablishedSub;
  StreamSubscription<ChannelReadEvent>? _channelSub;

  bool get isAttached => _userId != null;

  /// Привязка к аккаунту: соединение + подписка на `private-user.{id}`.
  ///
  /// Повторный attach тем же id — no-op; attach другого аккаунта
  /// пересоздаёт соединение. Без access-токена соединение не
  /// открывается (offline cold start — просто detached).
  Future<void> attach(String userId) async {
    if (_userId == userId) return;
    detach();
    _userId = userId;

    final apiUri = Uri.parse(_env.apiBaseUrl);
    final isTls = apiUri.scheme == 'https';

    debugPrint(
      'RealtimeClient: attach user=$userId → '
      '${isTls ? 'wss' : 'ws'}://${apiUri.host}/app/${_env.reverbAppKey}',
    );

    final client = PusherChannelsClient.websocket(
      options: PusherChannelsOptions.fromHost(
        scheme: isTls ? 'wss' : 'ws',
        host: apiUri.host,
        key: _env.reverbAppKey,
        port: apiUri.hasPort ? apiUri.port : (isTls ? 443 : 80),
      ),
      minimumReconnectDelayDuration: const Duration(seconds: 2),
      connectionErrorHandler: (error, trace, refresh) {
        debugPrint('RealtimeClient: connection error: $error');
        _setStatus(RealtimeStatus.reconnecting);
        // Reconnect-политика делегирована контроллеру; вызов refresh()
        // планирует повторную попытку с backoff.
        refresh();
      },
    );
    _client = client;

    _lifecycleSub = client.lifecycleStream.listen(_onLifecycle);
    _connectionEstablishedSub = client.onConnectionEstablished.listen(
      (_) => _subscribeUserChannel(),
    );

    _setStatus(RealtimeStatus.connecting);
    unawaited(client.connect());
  }

  /// Отключение от аккаунта: отписка + закрытие соединения.
  void detach() {
    _userId = null;
    _deduper.clear();
    unawaited(_channelSub?.cancel());
    _channelSub = null;
    _userChannel?.unsubscribe();
    _userChannel = null;
    unawaited(_lifecycleSub?.cancel());
    _lifecycleSub = null;
    unawaited(_connectionEstablishedSub?.cancel());
    _connectionEstablishedSub = null;
    final client = _client;
    _client = null;
    if (client != null) {
      unawaited(client.disconnect().catchError((_) {}));
      client.dispose();
    }
    _setStatus(RealtimeStatus.disconnected);
  }

  /// Фореграунд-триггер: при возврате в app досоединяемся,
  /// если соединение разорвано.
  void ensureConnected() {
    final client = _client;
    if (_userId == null || client == null) return;
    unawaited(client.reconnect().catchError((_) {}));
  }

  void _onLifecycle(PusherChannelsClientLifeCycleState state) {
    switch (state) {
      case PusherChannelsClientLifeCycleState.establishedConnection:
        _setStatus(RealtimeStatus.connected);
      case PusherChannelsClientLifeCycleState.pendingConnection:
        _setStatus(RealtimeStatus.connecting);
      case PusherChannelsClientLifeCycleState.reconnecting:
      case PusherChannelsClientLifeCycleState.connectionError:
        _setStatus(RealtimeStatus.reconnecting);
      case PusherChannelsClientLifeCycleState.disconnected:
        _setStatus(RealtimeStatus.disconnected);
      case PusherChannelsClientLifeCycleState.inactive:
      case PusherChannelsClientLifeCycleState.disposed:
      case PusherChannelsClientLifeCycleState.gotPusherError:
        break;
    }
  }

  /// Подписка на персональный канал `private-user.{userId}`.
  ///
  /// Авторизация — `POST {api}/api/v1/broadcasting/auth` через Dio
  /// (Bearer-токен подставляет interceptor apiClient). 401 → токен
  /// невалиден → onAuthFailure → пересчёт сессии. 403 → канал
  /// недоступен, сессию не трогаем.
  void _subscribeUserChannel() {
    final client = _client;
    final userId = _userId;
    if (client == null || userId == null) return;

    final channelName = 'private-user.$userId';
    final channel = client.privateChannel(
      channelName,
      authorizationDelegate: _BroadcastAuthDelegate(
        dio: _dio,
        endpoint: Uri.parse(
          '${_env.apiBaseUrl}${ApiConstants.apiPrefix}/broadcasting/auth',
        ),
        onAuthFailed: _onChannelAuthFailed,
      ),
    );

    _userChannel = channel;
    unawaited(_channelSub?.cancel());
    _channelSub = channel.bindToAll().listen(_onChannelEvent);
    channel.subscribe();
  }

  void _onChannelAuthFailed(dynamic error, StackTrace trace) {
    if (error is DioException && error.response?.statusCode == 401) {
      _onAuthFailure?.call();
      return;
    }
    debugPrint('RealtimeClient: channel auth failed: $error');
  }

  void _onChannelEvent(ChannelReadEvent event) {
    // Служебные события протокола — не бизнес-события.
    final name = event.name;
    if (name.startsWith('pusher:') || name.startsWith('pusher_internal:')) {
      if (name == 'pusher_internal:subscription_succeeded') {
        debugPrint('RealtimeClient: subscribed to ${event.channelName}');
      }
      return;
    }

    final parsed = RealtimeEvent.tryParse(
      channelName: event.channelName,
      eventName: name,
      data: event.tryGetDataAsMap(),
    );
    if (parsed == null) {
      debugPrint('RealtimeClient: malformed event "$name" — dropped');
      return;
    }

    // Дедупликация по event_id + refetch-триггер дальше по цепочке.
    final eventId = parsed.eventId;
    if (eventId != null && !_deduper.check(eventId)) return;

    _onEvent?.call(parsed);
  }

  RealtimeStatus _lastStatus = RealtimeStatus.disconnected;

  void _setStatus(RealtimeStatus status) {
    if (status != _lastStatus) {
      _lastStatus = status;
      debugPrint('RealtimeClient: → ${status.name}');
    }
    _onStatus?.call(status);
  }
}

/// Authorizer для приватных каналов через общий Dio-клиент.
///
/// EndpointAuthorizableChannelTokenAuthorizationDelegate ходит
/// через `package:http` и требует статические заголовки; Dio-вариант
/// читает Bearer-токен из secure storage на каждый запрос
/// (interceptor api_client) и различает 401/403.
class _BroadcastAuthDelegate
    implements
        EndpointAuthorizableChannelAuthorizationDelegate<
          PrivateChannelAuthorizationData
        > {
  _BroadcastAuthDelegate({
    required this._dio,
    required this.endpoint,
    this.onAuthFailed,
  });

  final Dio _dio;
  final Uri endpoint;

  @override
  final EndpointAuthFailedCallback? onAuthFailed;

  @override
  Future<PrivateChannelAuthorizationData> authorizationData(
    String socketId,
    String channelName,
  ) async {
    try {
      final response = await _dio.postUri<Map<String, dynamic>>(
        endpoint,
        data: {'socket_id': socketId, 'channel_name': channelName},
      );
      final auth = response.data?['auth'] as String?;
      if (auth == null) {
        throw StateError('broadcasting/auth: no "auth" field in response');
      }
      return PrivateChannelAuthorizationData(authKey: auth);
    } catch (error, trace) {
      onAuthFailed?.call(error, trace);
      rethrow;
    }
  }
}

/// Провайдер статуса соединения.
final realtimeStatusProvider =
    NotifierProvider<RealtimeStatusNotifier, RealtimeStatus>(
      RealtimeStatusNotifier.new,
    );

class RealtimeStatusNotifier extends Notifier<RealtimeStatus> {
  @override
  RealtimeStatus build() => RealtimeStatus.disconnected;

  void set(RealtimeStatus status) => state = status;
}

/// Провайдер realtime-клиента (singleton на сессию приложения).
///
/// Каждое входящее событие триггерит `SyncEngine.requestSync()` —
/// realtime остаётся «transport-only» оптимизацией, конвергенция
/// состояния идёт через REST pull (docs/01-architecture/realtime.md §8).
final realtimeClientProvider = Provider<RealtimeClient>((ref) {
  final client = RealtimeClient(
    dio: ref.read(apiClientProvider),
    env: EnvConfig.fromEnvironment(),
    onStatus: ref.read(realtimeStatusProvider.notifier).set,
    onEvent: (_) {
      // Событие = «что-то изменилось на сервере» → pull reconcile.
      // Дедупликация и guard-ы внутри requestSync защищают от лавины.
      unawaited(ref.read(syncEngineProvider).requestSync());
    },
    onAuthFailure: () {
      // 401 от broadcasting/auth = невалидный токен — то же
      // поведение, что у SyncEngine: чистим credentials и даём
      // session-контроллеру пересчитать состояние.
      ref.read(authRepositoryProvider).clearCredentials();
      ref.invalidate(appSessionControllerProvider);
    },
  );
  ref.onDispose(client.detach);
  return client;
});

/// Фореграунд-триггер: при возврате в app досоединяем WebSocket.
/// Регистрируется в [ChtoHochuApp] рядом с SyncLifecycleObserver.
class RealtimeLifecycleObserver extends WidgetsBindingObserver {
  RealtimeLifecycleObserver(this._ref);

  final Ref _ref;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _ref.read(realtimeClientProvider).ensureConnected();
    }
  }
}

final realtimeLifecycleObserverProvider = Provider<RealtimeLifecycleObserver>(
  (ref) => RealtimeLifecycleObserver(ref),
);
