<?php

namespace App\Services;

use App\Models\User;
use App\Notifications\UserPushNotification;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Notification;
use Illuminate\Support\Str;

class PushNotificationService
{
    /**
     * Отправить push-уведомление одному пользователю.
     */
    public function sendToUser(User $user, string $title, string $body, array $data = []): string
    {
        $traceId = isset($data['trace_id']) && is_string($data['trace_id']) && $data['trace_id'] !== ''
            ? $data['trace_id']
            : (string) Str::uuid();

        $tokens = $user->routeNotificationForFcm();

        $dataWithTrace = [
            ...$data,
            'trace_id' => $traceId,
        ];

        if ($tokens === []) {
            return $traceId;
        }

        Notification::send($user, new UserPushNotification($title, $body, $dataWithTrace));

        return $traceId;
    }

    /**
     * Отправить push-уведомление нескольким пользователям.
     *
     * @param iterable<User>|Collection<User> $users
     */
    public function sendToUsers(iterable $users, string $title, string $body, array $data = []): string
    {
        if ($users instanceof Collection) {
            $users = $users->all();
        } elseif (! is_array($users)) {
            $users = iterator_to_array($users, false);
        }

        $traceId = isset($data['trace_id']) && is_string($data['trace_id']) && $data['trace_id'] !== ''
            ? $data['trace_id']
            : (string) Str::uuid();

        $dataWithTrace = [
            ...$data,
            'trace_id' => $traceId,
        ];

        Notification::send($users, new UserPushNotification($title, $body, $dataWithTrace));

        return $traceId;
    }
}
