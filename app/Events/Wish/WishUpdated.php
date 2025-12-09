<?php

namespace App\Events\Wish;

use App\Models\Wish;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Событие: желание обновлено.
 * Канал: item.{itemId}
 */
class WishUpdated implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public Wish $wish,
        public array $updatedFields = []
    ) {}

    /**
     * Каналы для вещания.
     */
    public function broadcastOn(): array
    {
        $channels = [
            new PrivateChannel('item.' . $this->wish->id),
        ];

        // Также уведомляем канал списка, если желание привязано к списку
        if ($this->wish->wishlist_id) {
            $channels[] = new PrivateChannel('list.members.' . $this->wish->wishlist_id);
        }

        return $channels;
    }

    /**
     * Имя события для клиента.
     */
    public function broadcastAs(): string
    {
        return 'ItemUpdated';
    }

    /**
     * Данные для отправки клиенту.
     */
    public function broadcastWith(): array
    {
        return [
            'item' => [
                'id' => $this->wish->id,
                'wishlistId' => $this->wish->wishlist_id,
                'name' => $this->wish->name,
                'description' => $this->wish->description,
                'visibility' => $this->wish->visibility,
                'images' => $this->wish->images ?? [],
                'link' => $this->wish->url,
                'necessity' => $this->wish->necessity,
                'priority' => $this->wish->priority,
                'desiredPrice' => $this->wish->desired_price,
                'priceMin' => $this->wish->price_min,
                'priceMax' => $this->wish->price_max,
                'hidePrice' => (bool) $this->wish->hide_price,
                'status' => $this->wish->status,
                'inProgress' => (bool) $this->wish->in_progress,
                'allowClaiming' => (bool) $this->wish->allow_claiming,
                'sortIndex' => $this->wish->sort_index,
                'updatedAt' => optional($this->wish->updated_at)?->toISOString(),
            ],
            'updatedFields' => $this->updatedFields,
            'timestamp' => now()->toISOString(),
        ];
    }
}
