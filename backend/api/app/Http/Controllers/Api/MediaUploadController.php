<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\StoreMediaUploadRequest;
use App\Http\Resources\MediaUploadResource;
use App\Models\MediaUpload;
use App\Services\Media\MediaUploadService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MediaUploadController extends Controller
{
    public function __construct(
        private readonly MediaUploadService $media,
    ) {}

    /**
     * Инструкции на загрузку: presigned PUT на серверный object key.
     * Повтор с тем же client_id — тот же upload + свежий URL. 201.
     */
    public function store(StoreMediaUploadRequest $request): JsonResponse
    {
        [
            'upload' => $upload,
            'upload_url' => $url,
            'upload_headers' => $headers,
        ] = $this->media->createUpload($request->user(), $request->validated());

        return (new MediaUploadResource($upload))
            ->withUploadUrl($url, $headers)
            ->toResponse($request)
            ->setStatusCode(201);
    }

    /**
     * Подтверждение загрузки после успешного PUT.
     * Чужой upload_id — 404 (не раскрываем существование).
     */
    public function complete(Request $request, MediaUpload $mediaUpload): MediaUploadResource
    {
        $upload = $this->media->confirmUpload($request->user(), $mediaUpload);

        return new MediaUploadResource($upload);
    }
}
