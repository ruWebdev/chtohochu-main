<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class WishResource extends JsonResource
{
    /**
     * Преобразование ресурса в массив для API.
     */
    public function toArray(Request $request): array
    {
        $claimers = $this->whenLoaded('claimers');

        return [
            'id' => $this->id,
            'wishlist_id' => $this->wishlist_id,
            'name' => $this->name,
            'description' => $this->description,
            'visibility' => $this->visibility,
            'images' => $this->images ?? [],
            'link' => $this->url,
            'necessity' => $this->necessity,
            'priority' => $this->priority,
            'desired_price' => $this->desired_price,
            'price_min' => $this->price_min,
            'price_max' => $this->price_max,
            'hide_price' => (bool) $this->hide_price,
            'categories' => $this->tags ?? [],
            'status' => $this->status,
            'in_progress' => (bool) $this->in_progress,
            'claimers' => WishClaimerResource::collection($claimers ?? []),
            'allow_claiming' => (bool) $this->allow_claiming,
            'deadline_date' => optional($this->deadline_at)?->toISOString(),
            'sort_index' => $this->sort_index,
            'created_at' => optional($this->created_at)?->toISOString(),
            'updated_at' => optional($this->updated_at)?->toISOString(),
        ];
    }
}
