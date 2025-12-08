<?php

namespace App\Events\Wishlist;

use App\Models\Wish;
use App\Models\Wishlist;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PresenceChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Событие: в список добавлено новое желание.
 * Канал: presence-list.{listId}
 */
class WishlistItemAdded implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public Wishlist $wishlist,
        public Wish $wish
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
        return 'ListItemAdded';
    }

    /**
     * Данные для отправки клиенту.
     */
    public function broadcastWith(): array
    {
        return [
            'listId' => $this->wishlist->id,
            'item' => [
                'id' => $this->wish->id,
                'name' => $this->wish->name,
                'description' => $this->wish->description,
                'visibility' => $this->wish->visibility,
                'images' => $this->wish->images ?? [],
                'link' => $this->wish->url,
                'necessity' => $this->wish->necessity,
                'priority' => $this->wish->priority,
                'desiredPrice' => $this->wish->desired_price,
                'status' => $this->wish->status,
                'sortIndex' => $this->wish->sort_index,
                'createdAt' => optional($this->wish->created_at)?->toISOString(),
            ],
            'timestamp' => now()->toISOString(),
        ];
    }
}
