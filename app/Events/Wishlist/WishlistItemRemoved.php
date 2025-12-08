<?php

namespace App\Events\Wishlist;

use App\Models\Wishlist;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PresenceChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Событие: желание удалено из списка.
 * Канал: presence-list.{listId}
 */
class WishlistItemRemoved implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public Wishlist $wishlist,
        public string $wishId
    ) {}

    /**
     * Каналы для вещания.
     */
    public function broadcastOn(): array
    {
        return [
            new PresenceChannel('presence-list.' . $this->wishlist->id),
        ];
    }

    /**
     * Имя события для клиента.
     */
    public function broadcastAs(): string
    {
        return 'ListItemRemoved';
    }

    /**
     * Данные для отправки клиенту.
     */
    public function broadcastWith(): array
    {
        return [
            'listId' => $this->wishlist->id,
            'itemId' => $this->wishId,
            'timestamp' => now()->toISOString(),
        ];
    }
}
