<?php

namespace App\Http\Resources;

use App\Models\ShoppingList;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin ShoppingList
 */
class ShoppingListResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * `owner_id` + `members` нужны клиенту для совместных
     * списков: определить роль текущего пользователя и
     * отобразить участников. owner — участник неявно, в
     * `members` он не дублируется.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'title' => $this->title,
            'owner_id' => $this->owner_id,
            'created_at' => $this->created_at?->toIso8601String(),
            'updated_at' => $this->updated_at?->toIso8601String(),
            'items' => ShoppingItemResource::collection($this->whenLoaded('items')),
            'members' => PublicUserResource::collection($this->whenLoaded('members')),
            'revision' => (int) ($this->revision ?? 0),
        ];
    }
}
