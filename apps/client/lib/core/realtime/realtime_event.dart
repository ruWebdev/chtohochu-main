import 'dart:convert';

/// Конверт realtime-события по docs/20-backend/realtime-events.md.
///
/// Парсинг максимально терпимый: недостающие поля → `null`.
/// Событие без `event_id` не дедуплицируется, но всё равно доставляется
/// — контракт требует поле, отсутствие трактуем как malformed и логируем.
class RealtimeEvent {
  const RealtimeEvent({
    required this.channelName,
    required this.eventName,
    required this.eventId,
    required this.eventType,
    required this.entityType,
    required this.entityId,
    required this.revision,
    required this.actorId,
    required this.serverTimestamp,
    required this.payload,
  });

  /// Имя pusher-канала, с которого пришло событие (`private-user.{id}`).
  final String channelName;

  /// Имя pusher-события (broadcastAs / имя класса по умолчанию).
  final String eventName;

  /// Уникальный id события для дедупликации.
  final String? eventId;

  /// `<domain>.<entity>.<action>` из конверта.
  final String? eventType;

  final String? entityType;
  final String? entityId;

  /// Пер-entity ревизия для отбрасывания устаревших событий.
  final int? revision;

  /// Кто породил событие (для echo-suppression).
  final String? actorId;

  final String? serverTimestamp;

  /// Snapshot / delta / refetch-инструкция — интерпретирует потребитель.
  final Object? payload;

  /// Разбирает `data` pusher-события. `null` — если это не JSON-объект.
  static RealtimeEvent? tryParse({
    required String channelName,
    required String eventName,
    required Object? data,
  }) {
    final Map<String, dynamic> map;
    try {
      final decoded = data is String ? jsonDecode(data) : data;
      if (decoded is! Map) return null;
      map = decoded.cast<String, dynamic>();
    } catch (_) {
      return null;
    }

    final revision = map['revision'];

    return RealtimeEvent(
      channelName: channelName,
      eventName: eventName,
      eventId: map['event_id'] as String?,
      eventType: map['event_type'] as String?,
      entityType: map['entity_type'] as String?,
      entityId: map['entity_id'] as String?,
      revision: revision is int ? revision : int.tryParse('$revision'),
      actorId: map['actor_id'] as String?,
      serverTimestamp: map['server_timestamp'] as String?,
      payload: map['payload'],
    );
  }
}
