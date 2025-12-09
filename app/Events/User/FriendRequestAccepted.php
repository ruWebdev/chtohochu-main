<?php

namespace App\Events\User;

use App\Models\Friendship;
use App\Models\User;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Событие: запрос в друзья принят.
 * Канал: user.{userId}
 */
class FriendRequestAccepted implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public Friendship $friendship,
        public User $requester,
        public User $addressee
    ) {}

    /**
     * Канал для вещания — приватный канал того, кто отправлял запрос.
     */
    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('user.' . $this->requester->id),
        ];
    }

    /**
     * Имя события для клиента.
     */
    public function broadcastAs(): string
    {
        return 'FriendRequestAccepted';
    }

    /**
     * Данные для отправки клиенту.
     */
    public function broadcastWith(): array
    {
        return [
            'friendshipId' => $this->friendship->id,
            'userId' => $this->addressee->id,
            'userName' => $this->addressee->name,
            'userAvatar' => $this->addressee->avatar,
            'timestamp' => now()->toISOString(),
        ];
    }
}
