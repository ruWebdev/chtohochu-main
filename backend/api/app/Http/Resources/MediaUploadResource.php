<?php

namespace App\Http\Resources;

use App\Services\Media\MediaStorageGateway;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Ответ media upload: presigned URL передаётся отдельным полем,
 * remote_url — целевой постоянный URL объекта (заполняется на
 * complete; в инструкциях присутствует как будущий reference).
 */
class MediaUploadResource extends JsonResource
{
    private ?string $uploadUrl = null;

    /** @var array<string, string> */
    private array $uploadHeaders = [];

    public function withUploadUrl(string $url, array $headers = []): static
    {
        $this->uploadUrl = $url;
        $this->uploadHeaders = $headers;

        return $this;
    }

    public function toArray(Request $request): array
    {
        return [
            'upload_id' => $this->id,
            'upload_url' => $this->uploadUrl,
            'upload_headers' => (object) $this->uploadHeaders,
            'method' => 'PUT',
            'object_key' => $this->object_key,
            'remote_url' => $this->remote_url
                ?? $this->resolveProspectiveUrl(),
            'status' => $this->status,
            'expires_at' => $this->expires_at?->toIso8601String(),
            'purpose' => $this->purpose,
            'entity_id' => $this->entity_id,
            'client_id' => $this->client_id,
        ];
    }

    /**
     * Для pending-записи remote_url ещё не зафиксирован в БД, но он
     * детерминирован по disk+key — отдаём клиенту для локального
     * планирования (post-complete значение будет тем же).
     */
    private function resolveProspectiveUrl(): ?string
    {
        $disk = config("media.purposes.{$this->purpose}.disk");

        return $disk !== null
            ? app(MediaStorageGateway::class)->url($disk, $this->object_key)
            : null;
    }
}
