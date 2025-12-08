<?php

namespace App\Events\Wish;

use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PresenceChannel;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Событие: желание удалено.
 * Канал: private-item.{itemId}, presence-list.{listId}
 */
class WishDeleted implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public string $wishId,
        public ?string $wishlistId = null
    ) {}

    /**
     * Каналы для вещания.
     */
    public function broadcastOn(): array
    {
        $channels = [
            new PrivateChannel('private-item.' . $this->wishId),
        ];

        if ($this->wishlistId) {
            $channels[] = new PresenceChannel('presence-list.' . $this->wishlistId);
        }

        return $channels;
    }

    /**
     * Имя события для клиента.
     */
    public function broadcastAs(): string
    {
        return 'ItemDeleted';
    }

    /**
     * Данные для отправки клиенту.
     */
    public function broadcastWith(): array
    {
        return [
            'itemId' => $this->wishId,
            'listId' => $this->wishlistId,
            'timestamp' => now()->toISOString(),
        ];
    }
}
