<?php

namespace App\Http\Resources;

use App\Models\WishList;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin WishList
 */
class WishListResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * owner_id не отдаём — владелец хранится в БД
     * независимо от представления.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'title' => $this->title,
            'created_at' => $this->created_at?->toIso8601String(),
            'updated_at' => $this->updated_at?->toIso8601String(),
        ];
    }
}
