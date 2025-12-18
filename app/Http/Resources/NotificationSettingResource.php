<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class NotificationSettingResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'user_id' => $this->user_id,
            'pushEnabled' => (bool) $this->push_enabled,
            'friendRequests' => (bool) $this->friend_requests,
            'wishFulfilled' => (bool) $this->wish_fulfilled,
            'reminders' => (bool) $this->reminders,
            'newWishes' => (bool) $this->new_wishes,
            // Новые поля согласно спецификации
            'listInvites' => (bool) ($this->list_invites ?? true),
            'listMemberChanges' => (bool) ($this->list_member_changes ?? true),
            'wishComments' => (bool) ($this->wish_comments ?? true),
            'shoppingListInvites' => (bool) ($this->shopping_list_invites ?? true),
            'shoppingMemberChanges' => (bool) ($this->shopping_member_changes ?? true),
            'shoppingItemChecked' => (bool) ($this->shopping_item_checked ?? true),
            'systemAnnouncements' => (bool) ($this->system_announcements ?? true),
            'created_at' => optional($this->created_at)?->toISOString(),
            'updated_at' => optional($this->updated_at)?->toISOString(),
        ];
    }
}
