<?php

namespace App\Events\Wishlist;

use App\Models\Wishlist;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Событие: участник удалён из списка.
 * Канал: private-list.{listId}
 */
class WishlistParticipantRemoved implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public Wishlist $wishlist,
        public string $userId
    ) {}

    /**
     * Каналы для вещания.
     */
    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('private-list.' . $this->wishlist->id),
            new PrivateChannel('private-user.' . $this->userId),
        ];
    }

    /**
     * Имя события для клиента.
     */
    public function broadcastAs(): string
    {
        return 'ListParticipantRemoved';
    }

    /**
     * Данные для отправки клиенту.
     */
    public function broadcastWith(): array
    {
        return [
            'listId' => $this->wishlist->id,
            'userId' => $this->userId,
            'timestamp' => now()->toISOString(),
        ];
    }
}
