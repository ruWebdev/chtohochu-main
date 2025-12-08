<?php

namespace App\Events\Wishlist;

use App\Models\Wishlist;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PresenceChannel;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Событие: список желаний обновлён.
 * Канал: presence-list.{listId}
 */
class WishlistUpdated implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public Wishlist $wishlist,
        public array $updatedFields = []
    ) {}

    /**
     * Каналы для вещания.
     */
    public function broadcastOn(): array
    {
        return [
            new PresenceChannel('presence-list.' . $this->wishlist->id),
            new PrivateChannel('private-list.' . $this->wishlist->id),
        ];
    }

    /**
     * Имя события для клиента.
     */
    public function broadcastAs(): string
    {
        return 'ListUpdated';
    }

    /**
     * Данные для отправки клиенту.
     */
    public function broadcastWith(): array
    {
        return [
            'listId' => $this->wishlist->id,
            'fields' => $this->updatedFields,
            'name' => $this->wishlist->name,
            'description' => $this->wishlist->description,
            'visibility' => $this->wishlist->visibility,
            'status' => $this->wishlist->status,
            'avatar' => $this->wishlist->avatar,
            'cardColor' => $this->wishlist->card_color,
            'timestamp' => now()->toISOString(),
        ];
    }
}
