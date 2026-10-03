<?php

namespace App\Http\Resources;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Публичная проекция пользователя: поиск, друг.
 * Email и внутренние данные не отдаём.
 *
 * @mixin User
 */
class PublicUserResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'username' => $this->username,
            'avatar_url' => $this->avatar_url,
            'is_friend' => $request->user()?->isFriendWith($this->resource) ?? false,
        ];
    }
}
