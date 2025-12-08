<?php

namespace App\Events\System;

use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Событие: уведомление о техработах.
 * Канал: system-global
 */
class AppMaintenanceNotice implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public string $message,
        public ?string $startsAt = null,
        public ?string $endsAt = null
    ) {}

    /**
     * Каналы для вещания.
     */
    public function broadcastOn(): array
    {
        return [
            new Channel('system-global'),
        ];
    }

    /**
     * Имя события для клиента.
     */
    public function broadcastAs(): string
    {
        return 'AppMaintenanceNotice';
    }

    /**
     * Данные для отправки клиенту.
     */
    public function broadcastWith(): array
    {
        return [
            'message' => $this->message,
            'startsAt' => $this->startsAt,
            'endsAt' => $this->endsAt,
            'timestamp' => now()->toISOString(),
        ];
    }
}
