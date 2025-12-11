<?php

namespace App\Events\ShoppingList;

use App\Models\ShoppingListItem;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Событие: создан новый элемент списка покупок.
 * Канал: private-shopping-list.{listId}
 */
class ShoppingListItemCreated implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public ShoppingListItem $item,
    ) {}

    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('shopping-list.' . $this->item->shopping_list_id),
        ];
    }

    public function broadcastAs(): string
    {
        return 'ShoppingListItemCreated';
    }

    public function broadcastWith(): array
    {
        return [
            'item' => [
                'id' => $this->item->id,
                'shopping_list_id' => $this->item->shopping_list_id,
                'name' => $this->item->name,
                'quantity' => $this->item->quantity,
                'unit' => $this->item->unit,
                'is_purchased' => $this->item->is_purchased,
                'sort_index' => $this->item->sort_index,
                'image_url' => $this->item->image_url,
                'created_at' => $this->item->created_at?->toISOString(),
                'updated_at' => $this->item->updated_at?->toISOString(),
            ],
            'timestamp' => now()->toISOString(),
        ];
    }
}
