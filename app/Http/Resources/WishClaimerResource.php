<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class WishClaimerResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $user = $this->whenLoaded('user');

        return [
            'id' => $user?->id,
            'name' => $user?->name,
            'avatar' => $user?->avatar ?? null,
            'claimed_at' => optional($this->claimed_at)?->toISOString(),
            'is_secret' => (bool) $this->is_secret,
        ];
    }
}
