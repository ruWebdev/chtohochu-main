<?php

namespace App\Events\ShoppingList;

use App\Models\ShoppingList;
use App\Models\User;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Событие: участник удалён из списка покупок владельцем.
 * Канал: private-shopping-list.{listId}
 */
class ShoppingListParticipantRemoved implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public ShoppingList $shoppingList,
        public User $participant,
        public User $removedBy,
    ) {}

    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('shopping-list.' . $this->shoppingList->id),
        ];
    }

    public function broadcastAs(): string
    {
        return 'ShoppingListParticipantRemoved';
    }

    public function broadcastWith(): array
    {
        return [
            'list_id' => $this->shoppingList->id,
            'participant_id' => $this->participant->id,
            'participant_name' => $this->participant->name,
            'removed_by' => [
                'id' => $this->removedBy->id,
                'name' => $this->removedBy->name,
            ],
            'timestamp' => now()->toISOString(),
        ];
    }
}
