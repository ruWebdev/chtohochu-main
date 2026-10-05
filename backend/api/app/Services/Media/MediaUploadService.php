<?php

namespace App\Services\Media;

use App\Models\MediaUpload;
use App\Models\ShoppingList;
use App\Models\User;
use App\Models\Wish;
use Illuminate\Support\Str;

/**
 * Upload lifecycle (ADR-015):
 *
 *   create → pending  (presigned PUT выдан)
 *   complete → uploaded  (object проверен: существует, тип, размер)
 *   просрочен/невалидный объект → failed
 *
 * Идемпотентность: `client_id` клиента уникален на пользователя —
 * повторный create возвращает тот же upload и свежий presigned URL,
 * дубликатов объектов не образуется.
 */
class MediaUploadService
{
    public function __construct(
        private readonly MediaStorageGateway $storage,
    ) {}

    /**
     * Создать (или вернуть существующий по client_id) upload и выдать
     * инструкции для presigned PUT.
     *
     * @param  array{purpose:string, entity_id:?string, content_type:string, size:int, client_id:?string}  $data
     * @return array{upload: MediaUpload, upload_url: string, upload_headers: array<string, string>}
     */
    public function createUpload(User $user, array $data): array
    {
        $purpose = $data['purpose'];
        $config = config("media.purposes.$purpose");
        abort_unless($config !== null, 422, 'Unknown media purpose.');

        $entityId = $data['entity_id'] ?? null;
        $this->assertEntityAccess($user, $purpose, $entityId, $config);

        $clientId = $data['client_id'] ?? null;
        $upload = $clientId !== null
            ? MediaUpload::where('user_id', $user->id)
                ->where('client_id', $clientId)
                ->first()
            : null;

        if ($upload === null) {
            $key = $this->makeObjectKey($user, $purpose, $entityId, $data['content_type'], $config);
            $upload = MediaUpload::create([
                'user_id' => $user->id,
                'purpose' => $purpose,
                'entity_id' => $entityId,
                'client_id' => $clientId,
                'bucket' => config("filesystems.disks.{$config['disk']}.bucket"),
                'object_key' => $key,
                'content_type' => $data['content_type'],
                'declared_size' => $data['size'],
                'status' => 'pending',
                'expires_at' => now()->addMinutes(config('media.upload_ttl_minutes')),
            ]);
        }

        // Presigned URL не хранится — выдаётся свежий на каждый запрос
        // инструкций (повторный create продлевает окно загрузки).
        $signed = $this->storage->temporaryPutUrl(
            $config['disk'],
            $upload->object_key,
            $upload->content_type,
            $upload->expires_at,
        );

        // Не все S3-провайдеры подписывают Content-Type — без него
        // объект получает дефолтный MIME и не пройдёт complete.
        // Поэтому Content-Type отдаём обязательным заголовком PUT.
        $headers = collect($signed['headers'])
            ->map(fn ($v) => is_array($v) ? implode(',', $v) : $v)
            ->all();
        $headers['Content-Type'] = $upload->content_type;

        return [
            'upload' => $upload,
            'upload_url' => $signed['url'],
            'upload_headers' => $headers,
        ];
    }

    /**
     * Подтверждение загрузки: объект должен существовать, соответствовать
     * заявленному типу и не превышать лимит. remote_url принимаем только
     * свой — клиентский не доверяем.
     */
    public function confirmUpload(User $user, MediaUpload $upload): MediaUpload
    {
        abort_unless($upload->user_id === $user->id, 404);

        if ($upload->status === 'uploaded') {
            // Повторный complete — идемпотентен.
            return $upload;
        }

        abort_unless($upload->status === 'pending', 422, 'Upload is not pending.');

        if ($upload->isExpired()) {
            $upload->update(['status' => 'failed']);
            abort(422, 'Upload expired.');
        }

        $this->assertKeyInPurpose($upload);

        $disk = config("media.purposes.{$upload->purpose}.disk");
        $head = $this->storage->head($disk, $upload->object_key);

        // Объекта ещё нет — клиент мог вызвать complete раньше PUT.
        // Оставляем pending: повторный complete допустим.
        abort_unless($head['exists'], 422, 'Object not found.');

        $maxSize = config('media.max_upload_bytes');
        $valid = $head['size'] !== null
            && $head['size'] <= $maxSize
            && $head['mime'] === $upload->content_type;

        if (! $valid) {
            $upload->update(['status' => 'failed']);
            abort(422, 'Object violates upload constraints.');
        }

        $upload->update([
            'status' => 'uploaded',
            'remote_url' => $this->storage->url($disk, $upload->object_key),
            'uploaded_at' => now(),
        ]);

        return $upload;
    }

    /**
     * Удалить объекты и пометить записи deleted. Retryable — частичный
     * сбой S3 повторяется job'ой, удаление доменной сущности не зависит
     * от результата.
     */
    public function deleteForEntity(string $purpose, string $entityId): void
    {
        $disk = config("media.purposes.$purpose.disk");

        MediaUpload::where('purpose', $purpose)
            ->where('entity_id', $entityId)
            ->whereIn('status', ['pending', 'uploading', 'uploaded'])
            ->get()
            ->each(function (MediaUpload $upload) use ($disk) {
                $this->assertKeyInPurpose($upload);
                $this->storage->delete($disk, $upload->object_key);
                $upload->update(['status' => 'deleted']);
            });
    }

    /**
     * Ownership entity проверяется всегда: клиент не может получить
     * upload URL в чужой namespace. Чужая сущность — 404, как и для
     * wishes (не раскрываем существование).
     */
    private function assertEntityAccess(User $user, string $purpose, ?string $entityId, array $config): void
    {
        if ($config['entity_required'] && $entityId === null) {
            abort(422, 'entity_id is required for this purpose.');
        }

        if ($entityId === null) {
            return;
        }

        $owned = match ($purpose) {
            'wish' => Wish::whereKey($entityId)->where('owner_id', $user->id)->exists(),
            'shopping' => ShoppingList::whereKey($entityId)->where('owner_id', $user->id)->exists(),
            'avatar' => $entityId === $user->id,
            default => false,
        };

        abort_unless($owned, 404);
    }

    /**
     * Object key строится только на сервере из user id и purpose —
     * клиентский namespace подменить невозможно. `{imageId}` — uuid:
     * разные загрузки никогда не делят один key (immutability + cache).
     * `key_prefix` (chtohochu-*) — корневой namespace одного
     * общего bucket: ключи ЧтоХочу никогда не покидают его.
     */
    private function makeObjectKey(User $user, string $purpose, ?string $entityId, string $contentType, array $config): string
    {
        $ext = config("media.extensions.$contentType") ?? 'bin';
        $imageId = Str::uuid()->toString();

        $key = $config['entity_required']
            ? sprintf($config['key_pattern'], $user->id, $entityId, $imageId, $ext)
            : sprintf($config['key_pattern'], $user->id, $imageId, $ext);

        return $config['key_prefix'].$key;
    }

    /**
     * Defense-in-depth: любая storage-операция по сохранённой записи
     * обязана оставаться внутри chtohochu- namespace её purpose —
     * иначе cleanup/complete мог бы тронуть объект вне нашего prefix'а.
     */
    private function assertKeyInPurpose(MediaUpload $upload): void
    {
        $prefix = config("media.purposes.{$upload->purpose}.key_prefix");
        abort_unless(
            $prefix !== null && str_starts_with($upload->object_key, $prefix),
            422,
            'Object key outside purpose namespace.',
        );
    }
}
