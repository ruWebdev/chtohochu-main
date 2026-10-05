<?php

namespace App\Jobs;

use App\Services\Media\MediaUploadService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

/**
 * Retryable cleanup remote-объектов после удаления доменной сущности.
 *
 * Сам delete желания НЕ зависит от S3: объект при недоступности
 * storage остаётся orphan candidate, повторная попытка — через retry
 * job'ы. См. ADR-015 §deletion.
 */
class DeleteMediaObjects implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries = 5;

    public function __construct(
        public readonly string $purpose,
        public readonly string $entityId,
    ) {}

    public function handle(MediaUploadService $media): void
    {
        $media->deleteForEntity($this->purpose, $this->entityId);
    }
}
