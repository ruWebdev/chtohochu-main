<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ShoppingListItemResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $assignedUserName = $this->whenLoaded('assignedUser', function ($user) {
            return $user->name;
        });

        $completedByUserName = $this->whenLoaded('completedBy', function ($user) {
            return $user->name;
        });

        return [
            'id' => $this->id,
            'shopping_list_id' => $this->shopping_list_id,
            'name' => $this->name,
            'image_url' => $this->image_url ?? null,
            'quantity' => $this->quantity ?? 1,
            'unit' => $this->unit ?? 'шт',
            'priority' => $this->priority ?? null,
            'is_purchased' => (bool) $this->is_purchased,
            'completed_by' => $this->completed_by,
            'completed_by_name' => $completedByUserName,
            'completed_at' => optional($this->completed_at)?->toISOString(),
            'assigned_to' => $this->assigned_user_id,
            'assigned_to_name' => $assignedUserName,
            'event_date' => optional($this->event_date)?->toISOString(),
            'note' => $this->note ?? null,
            'sort_index' => $this->sort_index ?? 0,
            'created_at' => optional($this->created_at)?->toISOString(),
            'updated_at' => optional($this->updated_at)?->toISOString(),
        ];
    }
}
