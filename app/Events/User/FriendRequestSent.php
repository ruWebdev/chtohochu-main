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
 * Событие: отправлен запрос в друзья.
 * Канал: private-user.{userId}
 */
class FriendRequestSent implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public Friendship $friendship,
        public User $requester,
        public User $addressee
    ) {}

    /**
     * Канал для вещания — приватный канал получателя запроса.
     */
    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('private-user.' . $this->addressee->id),
        ];
    }

    /**
     * Имя события для клиента.
     */
    public function broadcastAs(): string
    {
        return 'FriendRequestSent';
    }

    /**
     * Данные для отправки клиенту.
     */
    public function broadcastWith(): array
    {
        return [
            'friendshipId' => $this->friendship->id,
            'userId' => $this->requester->id,
            'userName' => $this->requester->name,
            'userAvatar' => $this->requester->avatar,
            'message' => $this->friendship->message,
            'timestamp' => now()->toISOString(),
        ];
    }
}
