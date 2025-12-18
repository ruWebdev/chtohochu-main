<?php

namespace App\Events\System;

use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Событие: обновлено состояние индикаторов bottom navigation bar.
 * Канал: user.{userId}
 */
class BottomNavBadgeUpdated implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public string $userId,
        public array $badges
    ) {}

    /**
     * Канал для вещания — приватный канал пользователя.
     */
    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('user.' . $this->userId),
        ];
    }

    /**
     * Имя события для клиента.
     */
    public function broadcastAs(): string
    {
        return 'BottomNavBadgeUpdated';
    }

    /**
     * Данные для отправки клиенту.
     */
    public function broadcastWith(): array
    {
        return [
            'badges' => $this->badges,
            'timestamp' => now()->toISOString(),
        ];
    }
}
