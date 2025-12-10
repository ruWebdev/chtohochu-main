<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Ресурс записи истории изменений желания.
 */
class WishHistoryResource extends JsonResource
{
    /**
     * Преобразование ресурса в массив для API.
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'wish_id' => $this->wish_id,
            'user_id' => $this->user_id,
            'user_name' => $this->user?->name,
            'user_avatar' => $this->user?->avatar,
            'action' => $this->action,
            'changes' => $this->changes,
            'created_at' => optional($this->created_at)?->toISOString(),
        ];
    }
}
