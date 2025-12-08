<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class FriendResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $lastSeenAt = $this->last_seen_at;

        return [
            'id' => $this->id,
            'name' => $this->name,
            'email' => $this->email,
            'phone' => $this->phone,
            'username' => $this->username,
            'avatar' => $this->avatar,
            'is_online' => $lastSeenAt !== null && $lastSeenAt->greaterThanOrEqualTo(now()->subMinutes(5)),
            'last_seen_at' => optional($lastSeenAt)?->toISOString(),
            'friendship_status' => $this->friendship_status ?? null,
            'mutual_lists_count' => $this->mutual_lists_count ?? 0,
            'created_at' => optional($this->friendship_created_at ?? $this->created_at)?->toISOString(),
        ];
    }
}
