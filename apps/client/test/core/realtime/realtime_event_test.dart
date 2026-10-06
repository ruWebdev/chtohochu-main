import 'dart:convert';

import 'package:chtohochu/core/realtime/realtime_client.dart';
import 'package:chtohochu/core/realtime/realtime_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RealtimeEvent.tryParse', () {
    test('parses a full contract envelope from a JSON string', () {
      final event = RealtimeEvent.tryParse(
        channelName: 'private-user.u1',
        eventName: 'shopping_list.created',
        data: jsonEncode({
          'event_id': '01HXY9KRZ8',
          'event_type': 'shopping_list.created',
          'entity_type': 'shopping_list',
          'entity_id': 'list-1',
          'revision': 42,
          'actor_id': 'u2',
          'server_timestamp': '2026-10-06T12:00:00.000Z',
          'payload': {'title': 'Продукты'},
        }),
      );

      expect(event, isNotNull);
      expect(event!.eventId, '01HXY9KRZ8');
      expect(event.eventType, 'shopping_list.created');
      expect(event.entityType, 'shopping_list');
      expect(event.entityId, 'list-1');
      expect(event.revision, 42);
      expect(event.actorId, 'u2');
      expect((event.payload as Map)['title'], 'Продукты');
    });

    test('accepts a decoded Map as data', () {
      final event = RealtimeEvent.tryParse(
        channelName: 'private-user.u1',
        eventName: 'notification.created',
        data: {'event_id': 'e1', 'revision': '7'},
      );

      expect(event, isNotNull);
      expect(event!.revision, 7); // string revision → int
    });

    test('returns null for non-object payloads', () {
      expect(
        RealtimeEvent.tryParse(
          channelName: 'c',
          eventName: 'e',
          data: 'not json',
        ),
        isNull,
      );
      expect(
        RealtimeEvent.tryParse(channelName: 'c', eventName: 'e', data: 42),
        isNull,
      );
      expect(
        RealtimeEvent.tryParse(channelName: 'c', eventName: 'e', data: null),
        isNull,
      );
      expect(
        RealtimeEvent.tryParse(
          channelName: 'c',
          eventName: 'e',
          data: jsonEncode([1, 2, 3]),
        ),
        isNull,
      );
    });

    test('missing fields default to null — unknown events are safe', () {
      final event = RealtimeEvent.tryParse(
        channelName: 'c',
        eventName: 'unknown.future.event',
        data: jsonEncode({'some_new_field': true}),
      );

      expect(event, isNotNull);
      expect(event!.eventId, isNull);
      expect(event.entityType, isNull);
    });
  });

  group('RealtimeEventDeduper', () {
    test('first occurrence passes, repeat is dropped', () {
      final deduper = RealtimeEventDeduper();

      expect(deduper.check('e1'), isTrue);
      expect(deduper.check('e1'), isFalse);
      expect(deduper.check('e2'), isTrue);
    });

    test('is bounded — evicts oldest ids beyond capacity', () {
      final deduper = RealtimeEventDeduper(capacity: 3);

      deduper
        ..check('a')
        ..check('b')
        ..check('c')
        ..check('d'); // evicts 'a'

      expect(deduper.check('a'), isTrue); // вытеснен — считается новым
      expect(deduper.check('d'), isFalse); // ещё в окне — дубликат
    });

    test('clear resets the window', () {
      final deduper = RealtimeEventDeduper();
      deduper.check('e1');
      deduper.clear();
      expect(deduper.check('e1'), isTrue);
    });
  });
}
