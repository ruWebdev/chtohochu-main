<?php

namespace App\Events\ShoppingList;

use App\Models\ShoppingListItem;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Событие: обновлён элемент списка покупок.
 * Канал: private-shopping-list.{listId}
 */
class ShoppingListItemUpdated implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public ShoppingListItem $item,
        public array $changedFields = [],
    ) {}

    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('shopping-list.' . $this->item->shopping_list_id),
        ];
    }

    public function broadcastAs(): string
    {
        return 'ShoppingListItemUpdated';
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
                'completed_by' => $this->item->completed_by,
                'completed_by_name' => $this->item->completedBy?->name,
                'completed_at' => $this->item->completed_at?->toISOString(),
                'sort_index' => $this->item->sort_index,
                'image_url' => $this->item->image_url,
                'updated_at' => $this->item->updated_at?->toISOString(),
            ],
            'changed_fields' => $this->changedFields,
            'timestamp' => now()->toISOString(),
        ];
    }
}
