<?php

namespace App\Http\Resources;

use App\Models\Wish;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Публичная проекция желания для share-ссылки.
 *
 * Отдельный от WishResource ресурс намеренно: будущие private
 * поля не должны «протекать» в публичный ответ автоматически.
 * Заметка (description), id, list_id, owner_id, username,
 * timestamps и sync-поля здесь не отдаются.
 *
 * @mixin Wish
 */
class SharedWishResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'title' => $this->title,
            'price' => $this->price,
            'link' => $this->link,
            // image_url — публичный URL public-read bucket (ADR-015);
            // null передаётся как есть.
            'image_url' => $this->image_url,
            // owner только с именем и только если загружен явно —
            // внутри списка желаний owner у элементов не подгружается.
            'owner' => $this->whenLoaded('owner', fn () => [
                'name' => $this->owner->name,
            ]),
        ];
    }
}
