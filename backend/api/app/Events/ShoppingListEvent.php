<?php

namespace App\Events;

use App\Models\ShoppingItem;
use App\Models\ShoppingList;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Support\Str;

/**
 * Realtime-событие домена ShoppingList.
 *
 * Конверт — docs/20-backend/realtime-events.md §2:
 * event_id / event_type / entity_type / entity_id / revision /
 * actor_id / server_timestamp / payload.
 *
 * Каналы: `private-shopping-list.{listId}` (экран списка) +
 * `private-user.{id}` каждого участника — участник узнает о
 * membership/item-изменениях даже вне экрана списка. Клиент
 * дедуплицирует по event_id, событие — триггер pull reconcile,
 * состояние не применяется напрямую из payload.
 *
 * Получатели передаются снимком (`participantIds`), а не моделью:
 * для `shopping_list.deleted` / `participant.left` список или
 * строка membership уже удалены — deserialize живой модели
 * не пережил бы удаление.
 *
 * Диспатчить только после успешного COMMIT.
 */
class ShoppingListEvent implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets;

    /**
     * @param  list<string>  $participantIds  Получатели
     *                                        private-user.{id}: owner + members (+ уже удалённый
     *                                        участник для participant.left — он должен узнать о
     *                                        потере доступа).
     */
    public function __construct(
        public readonly string $eventType,
        public readonly string $entityType,
        public readonly string $entityId,
        public readonly int $revision,
        public readonly string $listId,
        public readonly array $participantIds,
        public readonly array $payload,
        public readonly ?string $actorId,
    ) {}

    /**
     * @return list<PrivateChannel>
     */
    public function broadcastOn(): array
    {
        $channels = [new PrivateChannel('shopping-list.'.$this->listId)];

        foreach (array_unique($this->participantIds) as $userId) {
            $channels[] = new PrivateChannel('user.'.$userId);
        }

        return $channels;
    }

    public function broadcastAs(): string
    {
        return $this->eventType;
    }

    /**
     * Конверт события по realtime-events.md §2.
     *
     * @return array<string, mixed>
     */
    public function broadcastWith(): array
    {
        return [
            'event_id' => (string) Str::uuid(),
            'event_type' => $this->eventType,
            'entity_type' => $this->entityType,
            'entity_id' => $this->entityId,
            'revision' => $this->revision,
            'actor_id' => $this->actorId,
            'server_timestamp' => now()->toIso8601String(),
            'payload' => $this->payload,
        ];
    }

    /**
     * Событие списка (created/updated/deleted/participant.*).
     *
     * @param  list<string>|null  $participantIds  null → текущие
     *                                             участники списка (owner + members).
     */
    public static function forList(
        ShoppingList $list,
        string $eventType,
        array $payload,
        ?string $actorId,
        ?array $participantIds = null,
    ): self {
        return new self(
            eventType: $eventType,
            entityType: 'shopping_list',
            entityId: $list->id,
            revision: (int) $list->revision,
            listId: $list->id,
            participantIds: $participantIds ?? $list->participantIds(),
            payload: $payload,
            actorId: $actorId,
        );
    }

    /**
     * Событие позиции (item.created/updated/deleted).
     */
    public static function forItem(
        ShoppingList $list,
        ShoppingItem $item,
        string $eventType,
        array $payload,
        ?string $actorId,
    ): self {
        return new self(
            eventType: $eventType,
            entityType: 'shopping_list_item',
            entityId: $item->id,
            revision: (int) $item->revision,
            listId: $list->id,
            participantIds: $list->participantIds(),
            payload: $payload,
            actorId: $actorId,
        );
    }
}
