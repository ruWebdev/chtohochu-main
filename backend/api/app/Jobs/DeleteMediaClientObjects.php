<?php

namespace App\Jobs;

use App\Services\Media\MediaUploadService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

/**
 * Точечный cleanup media-объектов по `client_id` — для удалённых
 * изображений живой сущности (редактирование желания убирает
 * отдельные фото, сущность при этом остаётся).
 *
 * Retryable, как [DeleteMediaObjects]: сбой S3 не должен ломать
 * обновление желания — повтор через retry job'ы.
 */
class DeleteMediaClientObjects implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries = 5;

    /**
     * @param  list<string>  $clientIds
     */
    public function __construct(
        public readonly string $purpose,
        public readonly array $clientIds,
        public readonly string $userId,
    ) {}

    public function handle(MediaUploadService $media): void
    {
        $media->deleteForClientIds($this->userId, $this->purpose, $this->clientIds);
    }
}
