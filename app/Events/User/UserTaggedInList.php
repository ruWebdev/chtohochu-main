<?php

namespace App\Events\User;

use App\Models\User;
use App\Models\Wishlist;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Событие: пользователя добавили в список как участника.
 * Канал: user.{userId}
 */
class UserTaggedInList implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public User $user,
        public Wishlist $wishlist,
        public User $inviter,
        public string $role = 'viewer'
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
        return 'UserTaggedInList';
    }

    /**
     * Данные для отправки клиенту.
     */
    public function broadcastWith(): array
    {
        return [
            'listId' => $this->wishlist->id,
            'listName' => $this->wishlist->name,
            'inviterId' => $this->inviter->id,
            'inviterName' => $this->inviter->name,
            'role' => $this->role,
            'timestamp' => now()->toISOString(),
        ];
    }
}
