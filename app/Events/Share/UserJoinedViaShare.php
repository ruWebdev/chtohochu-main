<?php

namespace App\Events\Share;

use App\Models\ShareToken;
use App\Models\User;
use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Событие присоединения пользователя к списку по share-ссылке.
 * Отправляется владельцу списка через WebSocket.
 */
class UserJoinedViaShare implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public ShareToken $shareToken,
        public User $joiner,
        public Model $entity
    ) {}

    /**
     * Канал для трансляции — приватный канал владельца.
     */
    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('user.' . $this->entity->owner_id),
        ];
    }

    /**
     * Имя события для клиента.
     */
    public function broadcastAs(): string
    {
        return 'share.user_joined';
    }

    /**
     * Данные для трансляции.
     */
    public function broadcastWith(): array
    {
        return [
            'entity_type' => $this->shareToken->entity_type,
            'entity_id' => $this->shareToken->entity_id,
            'entity_name' => $this->entity->name,
            'joiner' => [
                'id' => $this->joiner->id,
                'name' => $this->joiner->name,
                'avatar' => $this->joiner->avatar_url,
            ],
            'joined_at' => now()->toIso8601String(),
        ];
    }
}
