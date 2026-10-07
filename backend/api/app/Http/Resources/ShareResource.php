<?php

namespace App\Http\Resources;

use App\Models\Share;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin Share
 */
class ShareResource extends JsonResource
{
    /**
     * Capability-ответ создания share: токен и готовая публичная
     * ссылка. Base URL — из конфигурации (APP_SHARE_BASE_URL),
     * не хардкодится. `id`/`owner_id`/`shareable_id` не отдаём —
     * для клиента share существует как URL.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'token' => $this->token,
            'url' => rtrim((string) config('app.share_base_url'), '/')
                .'/s/'.$this->token,
        ];
    }
}
