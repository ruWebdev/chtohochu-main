<?php

namespace App\Services\Media;

use DateTimeInterface;

/**
 * Минимальный контракт работы с object storage.
 *
 * Все S3-вызовы изолированы здесь: доменная логика upload lifecycle
 * тестируется с fake-реализацией без реального S3.
 */
interface MediaStorageGateway
{
    /**
     * Presigned PUT URL: bucket/object/method/Content-Type/срок
     * зашиты в подпись — ключ нельзя переиспользовать для другого
     * объекта или другого типа контента.
     *
     * @return array{url: string, headers: array<string, string>}
     *                                                            `headers` — подписанные заголовки, клиент ОБЯЗАН их
     *                                                            отправить с PUT (минимум Content-Type).
     */
    public function temporaryPutUrl(
        string $disk,
        string $key,
        string $contentType,
        DateTimeInterface $expiresAt,
    ): array;

    /**
     * Метаданные объекта для подтверждения загрузки.
     *
     * @return array{exists: bool, size: int|null, mime: string|null}
     */
    public function head(string $disk, string $key): array;

    /**
     * Публичный URL объекта (immutable object → долгий cache lifetime
     * на стороне CDN/браузера; key уникален — busting не нужен).
     */
    public function url(string $disk, string $key): string;

    public function delete(string $disk, string $key): void;
}
