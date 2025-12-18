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
        // Новые поля согласно спецификации
        $settings->list_invites = $data['listInvites'] ?? $settings->list_invites;
        $settings->list_member_changes = $data['listMemberChanges'] ?? $settings->list_member_changes;
        $settings->wish_comments = $data['wishComments'] ?? $settings->wish_comments;
        $settings->shopping_list_invites = $data['shoppingListInvites'] ?? $settings->shopping_list_invites;
        $settings->shopping_member_changes = $data['shoppingMemberChanges'] ?? $settings->shopping_member_changes;
        $settings->shopping_item_checked = $data['shoppingItemChecked'] ?? $settings->shopping_item_checked;
        $settings->system_announcements = $data['systemAnnouncements'] ?? $settings->system_announcements;

        $settings->save();

        return response()->json([
            'data' => new NotificationSettingResource($settings),
        ]);
    }
}
