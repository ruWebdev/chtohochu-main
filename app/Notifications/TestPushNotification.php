<?php

namespace App\Notifications;

use Illuminate\Bus\Queueable;
use Illuminate\Notifications\Notification;
use NotificationChannels\Fcm\FcmChannel;
use NotificationChannels\Fcm\FcmMessage;
use NotificationChannels\Fcm\Resources\Notification as FcmNotification;

class TestPushNotification extends Notification
{
    use Queueable;

    public function __construct(
        public string $title,
        public string $body,
        public array $data = []
    ) {}

    public function via(object $notifiable): array
    {
        return [FcmChannel::class];
    }

    public function toFcm(object $notifiable): FcmMessage
    {
        return FcmMessage::create()
            ->notification(
                FcmNotification::create()
                    ->title($this->title)
                    ->body($this->body)
            )
            ->data($this->prepareData());
    }

    protected function prepareData(): array
    {
        if (empty($this->data)) {
            return [];
        }

        return array_map(
            static fn($value) => is_null($value) ? '' : (string) $value,
            $this->data
        );
    }
}
