<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Notification\UpdateNotificationSettingRequest;
use App\Http\Resources\NotificationSettingResource;
use App\Models\NotificationSetting;
use Illuminate\Http\Request;

class NotificationSettingController extends Controller
{
    /**
     * Получить текущие настройки уведомлений пользователя.
     */
    public function show(Request $request)
    {
        $user = $request->user();

        $settings = $user->notificationSetting;

        if (! $settings) {
            $settings = NotificationSetting::query()->create([
                'user_id' => $user->id,
            ]);
        }

        return response()->json([
            'data' => new NotificationSettingResource($settings),
        ]);
    }

    /**
     * Обновить настройки уведомлений пользователя.
     */
    public function update(UpdateNotificationSettingRequest $request)
    {
        $user = $request->user();

        $data = $request->validated();

        $settings = $user->notificationSetting;

        if (! $settings) {
            $settings = new NotificationSetting();
            $settings->user_id = $user->id;
        }

        $settings->push_enabled = $data['pushEnabled'] ?? $settings->push_enabled;
        $settings->friend_requests = $data['friendRequests'] ?? $settings->friend_requests;
        $settings->wish_fulfilled = $data['wishFulfilled'] ?? $settings->wish_fulfilled;
        $settings->reminders = $data['reminders'] ?? $settings->reminders;
        $settings->new_wishes = $data['newWishes'] ?? $settings->new_wishes;

        $settings->save();

        return response()->json([
            'data' => new NotificationSettingResource($settings),
        ]);
    }
}
