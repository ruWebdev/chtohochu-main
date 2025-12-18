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
 * Событие: добавлен новый участник в список покупок.
 * Канал: private-shopping-list.{listId}
 */
class ShoppingListParticipantAdded implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public ShoppingList $shoppingList,
        public User $participant,
        public User $addedBy,
    ) {}

    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('shopping-list.' . $this->shoppingList->id),
        ];
    }

    public function broadcastAs(): string
    {
        return 'ShoppingListParticipantAdded';
    }

    public function broadcastWith(): array
    {
        return [
            'list_id' => $this->shoppingList->id,
            'participant' => [
                'id' => $this->participant->id,
                'name' => $this->participant->name,
                'avatar' => $this->participant->avatar,
            ],
            'added_by' => [
                'id' => $this->addedBy->id,
                'name' => $this->addedBy->name,
            ],
            'timestamp' => now()->toISOString(),
        ];
    }
}
