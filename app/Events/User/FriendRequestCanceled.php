<?php

namespace App\Events\User;

use App\Models\User;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Событие: исходящая заявка в друзья отменена отправителем.
 * Канал: user.{addresseeId}
 */
class FriendRequestCanceled implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public string $friendshipId,
        public User $requester,
        public User $addressee
    ) {}

    /**
     * Канал для вещания — приватный канал получателя заявки.
     */
    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('user.' . $this->addressee->id),
        ];
    }

    /**
     * Имя события для клиента.
     */
    public function broadcastAs(): string
    {
        return 'FriendRequestCanceled';
    }

    /**
     * Данные для отправки клиенту.
     */
    public function broadcastWith(): array
    {
        return [
            'friendshipId' => $this->friendshipId,
            'userId' => $this->requester->id,
            'userName' => $this->requester->name,
            'userAvatar' => $this->requester->avatar,
            'timestamp' => now()->toISOString(),
        ];
    }
}
