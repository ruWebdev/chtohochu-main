<?php

namespace App\Http\Resources;

use App\Models\WishList;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Публичная проекция списка желаний для share-ссылки.
 *
 * Отдельный ресурс (не WishListResource): публичный ответ — это
 * осознанно собранная проекция, а не «всё, что в entity».
 * owner — только имя; желания — в public-проекции
 * SharedWishResource.
 *
 * @mixin WishList
 */
class SharedWishListResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'title' => $this->title,
            'owner' => [
                'name' => $this->owner->name,
            ],
            'wishes' => SharedWishResource::collection($this->wishes),
        ];
    }
}
