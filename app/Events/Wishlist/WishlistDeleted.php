<?php

namespace App\Events\Wishlist;

use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Событие: список желаний удалён.
 * Канал: private-list.{listId}
 */
class WishlistDeleted implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public string $wishlistId,
        public string $wishlistName,
        public array $participantIds = []
    ) {}

    /**
     * Каналы для вещания — уведомляем всех участников.
     */
    public function broadcastOn(): array
    {
        $channels = [
            new PrivateChannel('private-list.' . $this->wishlistId),
        ];

        // Также уведомляем каждого участника персонально
        foreach ($this->participantIds as $userId) {
            $channels[] = new PrivateChannel('private-user.' . $userId);
        }

        return $channels;
    }

    /**
     * Имя события для клиента.
     */
    public function broadcastAs(): string
    {
        return 'ListDeleted';
    }

    /**
     * Данные для отправки клиенту.
     */
    public function broadcastWith(): array
    {
        return [
            'listId' => $this->wishlistId,
            'listName' => $this->wishlistName,
            'timestamp' => now()->toISOString(),
        ];
    }
}
