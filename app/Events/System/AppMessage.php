<?php

namespace App\Events\System;

use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Событие: глобальное сообщение приложения.
 * Канал: system-global
 */
class AppMessage implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public string $title,
        public string $body,
        public string $type = 'info',
        public array $data = []
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
        return 'AppMessage';
    }

    /**
     * Данные для отправки клиенту.
     */
    public function broadcastWith(): array
    {
        return [
            'title' => $this->title,
            'body' => $this->body,
            'type' => $this->type,
            'data' => $this->data,
            'timestamp' => now()->toISOString(),
        ];
    }
}
