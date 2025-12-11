<?php

namespace App\Events\User;

use App\Models\User;
use App\Models\ShoppingList;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Событие: пользователя добавили в список покупок как участника.
 * Канал: user.{userId}
 */
class UserTaggedInShoppingList implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public User $user,
        public ShoppingList $shoppingList,
        public User $inviter,
    ) {}

    /**
     * Канал для вещания — приватный канал добавленного пользователя.
     */
    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('user.' . $this->user->id),
        ];
    }

    /**
     * Имя события для клиента.
     */
    public function broadcastAs(): string
    {
        return 'UserTaggedInShoppingList';
    }

    /**
     * Данные для отправки клиенту.
     */
    public function broadcastWith(): array
    {
        return [
            'listId' => $this->shoppingList->id,
            'listName' => $this->shoppingList->name,
            'inviterId' => $this->inviter->id,
            'inviterName' => $this->inviter->name,
            'timestamp' => now()->toISOString(),
        ];
    }
}
