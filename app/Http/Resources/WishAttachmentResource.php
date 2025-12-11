<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage;

/**
 * Ресурс прикреплённого файла к желанию.
 */
class WishAttachmentResource extends JsonResource
{
    /**
     * Преобразование ресурса в массив для API.
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'wish_id' => $this->wish_id,
            'file_name' => $this->file_name,
            'file_url' => $this->file_url ? Storage::disk('public')->url($this->file_url) : null,
            'preview_url' => $this->preview_url ? Storage::disk('public')->url($this->preview_url) : null,
            'thumbnail_url' => $this->thumbnail_url ? Storage::disk('public')->url($this->thumbnail_url) : null,
            'file_type' => $this->file_type,
            'file_size' => $this->file_size,
            'created_at' => optional($this->created_at)?->toISOString(),
        ];
    }
}
