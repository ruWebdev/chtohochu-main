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
            'created_at' => optional($this->created_at)?->toISOString(),
            'updated_at' => optional($this->updated_at)?->toISOString(),
        ];
    }
}
