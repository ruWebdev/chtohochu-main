<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class FriendRequestResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $from = $this->whenLoaded('requester');
        $to = $this->whenLoaded('addressee');

        return [
            'id' => $this->id,
            'from_user' => $from ? [
                'id' => $from->id,
                'name' => $from->name,
                'username' => $from->username,
                'avatar' => $from->avatar,
            ] : null,
            'to_user' => $to ? [
                'id' => $to->id,
                'name' => $to->name,
                'username' => $to->username,
                'avatar' => $to->avatar,
            ] : null,
            'status' => $this->status,
            'message' => $this->message,
            'created_at' => optional($this->created_at)?->toISOString(),
            'updated_at' => optional($this->updated_at)?->toISOString(),
        ];
    }
}
