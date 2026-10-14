<?php

namespace App\Http\Resources;

use App\Models\WishImage;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin WishImage
 */
class WishImageResource extends JsonResource
{
    /**
     * Дополнительное изображение желания (primary — image_url).
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'url' => $this->url,
            'sort_order' => $this->sort_order,
        ];
    }
}
