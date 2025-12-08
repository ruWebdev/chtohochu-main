<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class WishlistResource extends JsonResource
{
    /**
     * Преобразование ресурса в массив для API.
     */
    public function toArray(Request $request): array
    {
        $owner = $this->whenLoaded('owner');
        $participants = $this->whenLoaded('participants');
        $wishes = $this->whenLoaded('wishes');

        return [
            'id' => $this->id,
            'owner_id' => $this->owner_id,
            'owner_name' => $owner?->name,
            'owner_avatar' => $owner?->avatar ?? null,
            'name' => $this->name,
            'description' => $this->description,
            'visibility' => $this->visibility,
            'status' => $this->status,
            'avatar' => $this->avatar,
            'card_color' => $this->card_color,
            'participants' => WishlistUserResource::collection($participants ?? []),
            'sort_order' => $this->wishes_sort,
            'categories' => $this->tags ?? [],
            'reminder_date' => optional($this->reminder_at)?->toISOString(),
            'allow_claiming' => (bool) $this->allow_claiming,
            'show_claimers' => (bool) $this->show_claimers,
            'is_favorite' => method_exists($this->resource, 'isFavoriteForUser')
                ? $this->resource->isFavoriteForUser($request->user())
                : false,
            'created_at' => optional($this->created_at)?->toISOString(),
            'updated_at' => optional($this->updated_at)?->toISOString(),
            'wishes' => WishResource::collection($wishes ?? []),
        ];
    }
}
