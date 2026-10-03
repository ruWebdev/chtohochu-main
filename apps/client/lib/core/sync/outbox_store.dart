import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// Операции outbox.
abstract final class OutboxOp {
  static const String create = 'create';
  static const String update = 'update';
  static const String delete = 'delete';
}

/// Постановка операций в outbox с compaction.
///
/// Все вызовы выполняются ВНУТРИ транзакции локальной мутации —
/// enqueue никогда не вызывается отдельно от изменения сущности.
///
/// Правила компактификации (per entity):
///   create + update*  → один create с финальным payload
///   create + delete   → ничего не отправляем (pending create снимается,
///                       вызывающий код удаляет сущность физически)
///   update + update   → один update с последним состоянием
///   update + delete   → один delete
class OutboxStore {
  const OutboxStore(this._db);

  final AppDatabase _db;

  /// Все незавершённые операции сущности (pending И failed) внутри
  /// текущей транзакции. Failed тоже участвует в compaction: новая
  /// локальная мутация реанимирует failed-операцию, а не создаёт
  /// конфликтующую пару (например, failed create + update привёл бы
  /// к PATCH несуществующей сущности → 404 → потере данных).
  Future<List<OutboxEntry>> _opsFor(String ownerId, String entityId) =>
      _db.opsFor(ownerId, entityId);

  /// Сущность ни разу не была создана на сервере: есть create-операция
  /// в любом статусе (pending или failed — сервер её не принял).
  /// Используется при delete: create+delete до первого успешного push
  /// не должен порождать HTTP-запросов вовсе.
  Future<bool> hasUnsyncedCreate(String ownerId, String entityId) async {
    final ops = await _opsFor(ownerId, entityId);
    return ops.any((o) => o.operation == OutboxOp.create);
  }

  /// Поставить операцию в очередь с compaction.
  ///
  /// [payload] — snapshot полей сущности (для create/update).
  Future<void> enqueue({
    required String ownerId,
    required String entityType,
    required String entityId,
    required String operation,
    Map<String, dynamic>? payload,
  }) async {
    final existing = await _opsFor(ownerId, entityId);
    final pendingCreate = existing
        .where((o) => o.operation == OutboxOp.create)
        .firstOrNull;

    switch (operation) {
      case OutboxOp.create:
        // Повторный create той же сущности — нормализуем к одному.
        await _removeOps(existing);
        await _insert(
          ownerId: ownerId,
          entityType: entityType,
          entityId: entityId,
          operation: OutboxOp.create,
          payload: payload,
        );
      case OutboxOp.update:
        if (pendingCreate != null) {
          // create + update → create с финальным состоянием.
          // Payload МЕРЖИТСЯ поверх create: update-payload не
          // содержит identity-полей (`id`, `list_id`) — замена
          // вчистую потеряла бы серверную identity и parent-link.
          final merged = <String, dynamic>{
            ...jsonDecode(pendingCreate.payloadJson ?? '{}')
                as Map<String, dynamic>,
            ...?payload,
          };
          await _revive(pendingCreate.id, merged);
        } else if (existing.any((o) => o.operation == OutboxOp.delete)) {
          final deleteOp = existing.firstWhere(
            (o) => o.operation == OutboxOp.delete,
          );
          if (deleteOp.status == 'pending') {
            // update после pending delete невозможен из UI —
            // защитно оставляем delete (сущность всё равно удалится).
            return;
          }
          // FAILED delete — другой случай: tombstone снят
          // (_restoreTombstone), сущность снова видима и редактируема.
          // Тихий drop новой мутации потерял бы локальные изменения
          // без outbox-операции — расхождение навсегда. Новое
          // намерение пользователя замещает failed-операцию.
          await _removeOps(existing);
          await _insert(
            ownerId: ownerId,
            entityType: entityType,
            entityId: entityId,
            operation: OutboxOp.update,
            payload: payload,
          );
        } else {
          final pendingUpdate = existing
              .where((o) => o.operation == OutboxOp.update)
              .firstOrNull;
          if (pendingUpdate != null) {
            await _revive(pendingUpdate.id, payload);
          } else {
            await _insert(
              ownerId: ownerId,
              entityType: entityType,
              entityId: entityId,
              operation: OutboxOp.update,
              payload: payload,
            );
          }
        }
      case OutboxOp.delete:
        await _removeOps(existing);
        if (pendingCreate != null) {
          // create + delete → на сервер ничего не уходит.
          return;
        }
        await _insert(
          ownerId: ownerId,
          entityType: entityType,
          entityId: entityId,
          operation: OutboxOp.delete,
        );
    }
  }

  /// Снять выполненную операцию.
  Future<void> complete(int opId) =>
      (_db.delete(_db.outboxEntries)..where((o) => o.id.equals(opId))).go();

  /// Снять все операции сущности (entity удалена remote — reconcile).
  Future<void> dropEntityOps(String ownerId, String entityId) =>
      (_db.delete(_db.outboxEntries)..where(
            (o) => o.ownerId.equals(ownerId) & o.entityId.equals(entityId),
          ))
          .go();

  /// Зафиксировать recoverable failure: attempts++, backoff.
  Future<void> markRetry(OutboxEntry op, String error) {
    return (_db.update(
      _db.outboxEntries,
    )..where((o) => o.id.equals(op.id))).write(
      OutboxEntriesCompanion(
        attempts: Value(op.attempts + 1),
        lastError: Value(error),
        nextRetryAt: Value(_nextRetryAt(op.attempts + 1)),
      ),
    );
  }

  /// Permanent failure (422) — не ретраим, сохраняем диагностику.
  Future<void> markFailed(OutboxEntry op, String error) {
    return (_db.update(
      _db.outboxEntries,
    )..where((o) => o.id.equals(op.id))).write(
      OutboxEntriesCompanion(
        status: const Value('failed'),
        lastError: Value(error),
      ),
    );
  }

  /// Exponential backoff: 5s · 2^(attempts-1), cap 15 минут.
  static DateTime _nextRetryAt(int attempts) {
    final seconds = 5 << (attempts - 1).clamp(0, 7);
    final capped = seconds > 900 ? 900 : seconds;
    return DateTime.now().add(Duration(seconds: capped));
  }

  Future<void> _removeOps(List<OutboxEntry> ops) async {
    for (final op in ops) {
      await (_db.delete(
        _db.outboxEntries,
      )..where((o) => o.id.equals(op.id))).go();
    }
  }

  /// Обновить payload операции и реанимировать её для отправки:
  /// failed → pending, backoff/attempts/lastError сбрасываются.
  /// Новая локальная мутация — это новое намерение пользователя,
  /// старая ошибка её не должна блокировать.
  Future<void> _revive(int opId, Map<String, dynamic>? payload) {
    return (_db.update(
      _db.outboxEntries,
    )..where((o) => o.id.equals(opId))).write(
      OutboxEntriesCompanion(
        payloadJson: Value(payload == null ? null : jsonEncode(payload)),
        status: const Value('pending'),
        attempts: const Value(0),
        lastError: const Value(null),
        nextRetryAt: const Value(null),
      ),
    );
  }

  Future<void> _insert({
    required String ownerId,
    required String entityType,
    required String entityId,
    required String operation,
    Map<String, dynamic>? payload,
  }) {
    return _db
        .into(_db.outboxEntries)
        .insert(
          OutboxEntriesCompanion(
            ownerId: Value(ownerId),
            entityType: Value(entityType),
            entityId: Value(entityId),
            operation: Value(operation),
            payloadJson: Value(payload == null ? null : jsonEncode(payload)),
            createdAt: Value(DateTime.now()),
          ),
        );
  }
}
