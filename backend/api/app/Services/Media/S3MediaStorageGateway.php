<?php

namespace App\Services\Media;

use DateTimeInterface;
use Illuminate\Support\Facades\Storage;

class S3MediaStorageGateway implements MediaStorageGateway
{
    public function temporaryPutUrl(
        string $disk,
        string $key,
        string $contentType,
        DateTimeInterface $expiresAt,
    ): array {
        return Storage::disk($disk)->temporaryUploadUrl(
            $key,
            $expiresAt,
            ['ContentType' => $contentType],
        );
    }

    public function head(string $disk, string $key): array
    {
        $storage = Storage::disk($disk);

        if (! $storage->exists($key)) {
            return ['exists' => false, 'size' => null, 'mime' => null];
        }

        return [
            'exists' => true,
            'size' => $storage->size($key),
            'mime' => $storage->mimeType($key),
        ];
    }

    public function url(string $disk, string $key): string
    {
        return Storage::disk($disk)->url($key);
    }

    public function delete(string $disk, string $key): void
    {
        Storage::disk($disk)->delete($key);
    }
}
