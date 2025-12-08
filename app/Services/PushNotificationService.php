<?php

namespace App\Services;

use App\Models\User;
use App\Notifications\UserPushNotification;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Notification;

class PushNotificationService
{
    /**
     * Отправить push-уведомление одному пользователю.
     */
    public function sendToUser(User $user, string $title, string $body, array $data = []): void
    {
        Notification::send($user, new UserPushNotification($title, $body, $data));
    }

    /**
     * Отправить push-уведомление нескольким пользователям.
     *
     * @param iterable<User>|Collection<User> $users
     */
    public function sendToUsers(iterable $users, string $title, string $body, array $data = []): void
    {
        if ($users instanceof Collection) {
            $users = $users->all();
        }

        Notification::send($users, new UserPushNotification($title, $body, $data));
    }
}
