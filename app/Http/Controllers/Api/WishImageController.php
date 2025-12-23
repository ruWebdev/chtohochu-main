<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Wishlist\UploadWishImageRequest;
use App\Http\Resources\WishResource;
use App\Models\Wish;
use App\Models\WishAttachment;
use Illuminate\Support\Facades\Storage;
use Intervention\Image\ImageManager;
use Intervention\Image\Drivers\Imagick\Driver as ImagickDriver;

class WishImageController extends Controller
{
    /**
     * Загрузка и обработка изображения для желания.
     * Генерирует две webp-версии: full (1200px) и thumbnail/preview (200px).
     */
    public function store(UploadWishImageRequest $request, Wish $wish)
    {
        $this->authorize('update', $wish);

        $file = $request->file('image');

        $manager = new ImageManager(new ImagickDriver());
        $image = $manager->read($file->getPathname());

        $basePath = 'wish-images/' . $wish->id;

        // Генерация двух размеров (по длинной стороне): 1200px и 200px
        // Важно: scaleDown мутирует объект, поэтому клонируем перед каждым ресайзом
        $full = (clone $image)->scaleDown(1200, 1200);
        $thumb = (clone $image)->scaleDown(200, 200);

        $unique = uniqid('img_', true);
        $fullPath = $basePath . '/' . $unique . '_full.webp';
        $thumbPath = $basePath . '/' . $unique . '_thumb.webp';

        Storage::disk('public')->put($fullPath, (string) $full->toWebp(80));
        Storage::disk('public')->put($thumbPath, (string) $thumb->toWebp(80));

        // Создаём запись вложения
        $attachment = WishAttachment::query()->create([
            'wish_id' => $wish->id,
            'file_name' => $file->getClientOriginalName(),
            'file_url' => $fullPath,
            // Для совместимости preview указываем на thumbnail (200px)
            'preview_url' => $thumbPath,
            'thumbnail_url' => $thumbPath,
            'file_type' => $file->getClientMimeType(),
            'file_size' => $file->getSize(),
        ]);

        // Обновляем поле images в желании (массив full-URL в файловом хранилище)
        $fullUrls = $wish->attachments()
            ->where('file_type', 'like', 'image/%')
            ->orderBy('created_at')
            ->pluck('file_url')
            ->filter()
            ->values()
            ->all();

        $wish->images = $fullUrls;
        $wish->save();

        $wish->load(['owner', 'claimers.user', 'comments', 'likes', 'history', 'attachments']);

        return response()->json([
            'message' => __('wishlist.wish_updated'),
            'data' => new WishResource($wish),
        ]);
    }

    /**
     * Удаление изображения желания.
     */
    public function destroy(Wish $wish, int $index)
    {
        $this->authorize('update', $wish);

        // Находим нужное изображение по индексу в упорядоченном списке image-вложений
        $attachmentQuery = $wish->attachments()
            ->where('file_type', 'like', 'image/%')
            ->orderBy('created_at');

        $attachment = $attachmentQuery
            ->skip($index)
            ->first();

        if (!$attachment) {
            abort(404);
        }

        // Удаляем файлы с диска
        $pathsToDelete = array_filter([
            $attachment->file_url,
            $attachment->preview_url,
            $attachment->thumbnail_url,
        ]);

        if (!empty($pathsToDelete)) {
            Storage::disk('public')->delete($pathsToDelete);
        }

        $attachment->delete();

        // Пересобираем массив full-URL для поля images
        $fullUrls = $wish->attachments()
            ->where('file_type', 'like', 'image/%')
            ->orderBy('created_at')
            ->pluck('file_url')
            ->filter()
            ->values()
            ->all();

        $wish->images = $fullUrls;
        $wish->save();

        $wish->load(['owner', 'claimers.user', 'comments', 'likes', 'history', 'attachments']);

        return response()->json([
            'message' => __('wishlist.wish_updated'),
            'data' => new WishResource($wish),
        ]);
    }
}
