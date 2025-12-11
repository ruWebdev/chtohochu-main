<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ShoppingListResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $owner = $this->whenLoaded('owner');
        $participants = $this->whenLoaded('participants');
        $items = $this->whenLoaded('items');

        return [
            'id' => $this->id,
            'name' => $this->name,
            'description' => $this->description,
            'visibility' => $this->visibility ?? 'personal',
            'is_shared' => (bool) $this->is_shared,
            'status' => $this->status,
            'avatar' => $this->avatar,
            'card_color' => $this->card_color,
            'owner_id' => $this->owner_id,
            'owner_name' => $owner?->name,
            'owner_avatar' => $owner?->avatar ?? null,
            'participants' => WishlistUserResource::collection($participants ?? []),
            'sort_order' => $this->sort_order ?? 0,
            'deadline_date' => optional($this->deadline_at)?->toISOString(),
            'event_name' => $this->event_name,
            'notifications_enabled' => (bool) $this->notifications_enabled,
            'items' => ShoppingListItemResource::collection($items ?? []),
            'created_at' => optional($this->created_at)?->toISOString(),
            'updated_at' => optional($this->updated_at)?->toISOString(),
        ];
    }
}
