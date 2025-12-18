<?php

namespace App\Events\Share;

use App\Models\ShareToken;
use App\Models\User;
use App\Models\Wish;
use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Событие копирования желания по share-ссылке.
 * Отправляется владельцу оригинального желания через WebSocket.
 */
class WishAddedViaShare implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public ShareToken $shareToken,
        public User $copier,
        public Wish $originalWish,
        public Wish $newWish
    ) {}

    /**
     * Канал для трансляции — приватный канал владельца оригинала.
     */
    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('user.' . $this->originalWish->owner_id),
        ];
    }

    /**
     * Имя события для клиента.
     */
    public function broadcastAs(): string
    {
        return 'share.wish_copied';
    }

    /**
     * Данные для трансляции.
     */
    public function broadcastWith(): array
    {
        return [
            'original_wish_id' => $this->originalWish->id,
            'original_wish_name' => $this->originalWish->name,
            'copier' => [
                'id' => $this->copier->id,
                'name' => $this->copier->name,
                'avatar' => $this->copier->avatar_url,
            ],
            'copied_at' => now()->toIso8601String(),
        ];
    }
}
