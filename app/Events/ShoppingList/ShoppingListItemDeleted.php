<?php

namespace App\Events\ShoppingList;

use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Событие: удалён элемент списка покупок.
 * Канал: private-shopping-list.{listId}
 */
class ShoppingListItemDeleted implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public string $itemId,
        public string $shoppingListId,
    ) {}

    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('shopping-list.' . $this->shoppingListId),
        ];
    }

    public function broadcastAs(): string
    {
        return 'ShoppingListItemDeleted';
    }

    public function broadcastWith(): array
    {
        return [
            'item_id' => $this->itemId,
            'shopping_list_id' => $this->shoppingListId,
            'timestamp' => now()->toISOString(),
        ];
    }
}
