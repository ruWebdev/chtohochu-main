<?php

namespace App\Events\Wishlist;

use App\Models\User;
use App\Models\Wishlist;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Событие: в список добавлен участник.
 * Канал: private-list.{listId}
 */
class WishlistParticipantAdded implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public Wishlist $wishlist,
        public User $participant,
        public string $role = 'viewer'
    ) {}

    /**
     * Каналы для вещания.
     */
    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('private-list.' . $this->wishlist->id),
        ];
    }

    /**
     * Имя события для клиента.
     */
    public function broadcastAs(): string
    {
        return 'ListParticipantAdded';
    }

    /**
     * Данные для отправки клиенту.
     */
    public function broadcastWith(): array
    {
        return [
            'listId' => $this->wishlist->id,
            'userId' => $this->participant->id,
            'userName' => $this->participant->name,
            'userAvatar' => $this->participant->avatar,
            'role' => $this->role,
            'timestamp' => now()->toISOString(),
        ];
    }
}
