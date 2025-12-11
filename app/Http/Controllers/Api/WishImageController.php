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
     * Генерирует три webp-версии: full (1200px), preview (300px), thumbnail (80px).
     */
    public function store(UploadWishImageRequest $request, Wish $wish)
    {
        $this->authorize('update', $wish);

        $file = $request->file('image');

        $manager = new ImageManager(new ImagickDriver());
        $image = $manager->read($file->getPathname());

        $basePath = 'wish-images/' . $wish->id;

        // Генерация трёх размеров (по длинной стороне)
        // Важно: scaleDown мутирует объект, поэтому клонируем перед каждым ресайзом
        $full = (clone $image)->scaleDown(1200, 1200);
        $preview = (clone $image)->scaleDown(300, 300);
        $thumb = (clone $image)->scaleDown(80, 80);

        $unique = uniqid('img_', true);
        $fullPath = $basePath . '/' . $unique . '_full.webp';
        $previewPath = $basePath . '/' . $unique . '_preview.webp';
        $thumbPath = $basePath . '/' . $unique . '_thumb.webp';

        Storage::disk('public')->put($fullPath, (string) $full->toWebp(80));
        Storage::disk('public')->put($previewPath, (string) $preview->toWebp(80));
        Storage::disk('public')->put($thumbPath, (string) $thumb->toWebp(80));

        // Создаём запись вложения
        $attachment = WishAttachment::query()->create([
            'wish_id' => $wish->id,
            'file_name' => $file->getClientOriginalName(),
            'file_url' => $fullPath,
            'preview_url' => $previewPath,
            'thumbnail_url' => $thumbPath,
            'file_type' => $file->getClientMimeType(),
            'file_size' => $file->getSize(),
        ]);

        // Обновляем поле images в желании (массив превью-URL)
        $previewUrls = $wish->attachments()
            ->where('file_type', 'like', 'image/%')
            ->orderBy('created_at')
            ->pluck('preview_url')
            ->filter()
            ->values()
            ->all();

        $wish->images = $previewUrls;
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

        // Пересобираем массив preview-URL для поля images
        $previewUrls = $wish->attachments()
            ->where('file_type', 'like', 'image/%')
            ->orderBy('created_at')
            ->pluck('preview_url')
            ->filter()
            ->values()
            ->all();

        $wish->images = $previewUrls;
        $wish->save();

        $wish->load(['owner', 'claimers.user', 'comments', 'likes', 'history', 'attachments']);

        return response()->json([
            'message' => __('wishlist.wish_updated'),
            'data' => new WishResource($wish),
        ]);
    }
}
