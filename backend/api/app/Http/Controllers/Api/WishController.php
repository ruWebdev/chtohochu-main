<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\StoreWishRequest;
use App\Http\Requests\Api\UpdateWishRequest;
use App\Http\Resources\WishResource;
use App\Jobs\DeleteMediaClientObjects;
use App\Models\Wish;
use App\Models\WishImage;
use Illuminate\Database\QueryException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;

class WishController extends Controller
{
    /**
     * Желания текущего пользователя, created_at DESC.
     * owner_id из query не принимается — всегда auth()->id().
     */
    public function index(Request $request): AnonymousResourceCollection
    {
        $wishes = $request->user()
            ->wishes()
            ->with('images')
            ->latest('created_at')
            ->get();

        return WishResource::collection($wishes);
    }

    /**
     * Создание желания. Владелец — auth()->id(), никогда
     * не принимается из request body. `id` опционален:
     * client-generated UUID для offline-first; повтор того
     * же UUID (lost-response retry) → 409, дубликата нет. 201.
     */
    public function store(StoreWishRequest $request): JsonResponse
    {
        $id = $request->validated('id');
        abort_if(
            $id !== null && Wish::whereKey($id)->exists(),
            409,
            'Resource already exists.'
        );

        $validated = $request->validated();
        // images — не атрибут wishes: достаём до create.
        $images = $validated['images'] ?? [];
        unset($validated['images']);

        try {
            // Желание и его изображения — одна транзакция:
            // без частично созданных состояний.
            $wish = DB::transaction(function () use ($request, $validated, $images) {
                $wish = $request->user()->wishes()->create($validated);
                $this->replaceImages($wish, $images);

                return $wish;
            });
        } catch (QueryException $e) {
            // Гонка между exists() и insert — тот же 409.
            abort_if($this->isDuplicateKeyViolation($e), 409, 'Resource already exists.');

            throw $e;
        }

        // DB-дефолты (priority и пр.) create() в модель не
        // подтягивает — refresh, чтобы ответ был точным.
        $wish->refresh()->load('images');

        return (new WishResource($wish))
            ->toResponse($request)
            ->setStatusCode(201);
    }

    /**
     * Просмотр желания. Только владелец (WishPolicy::view).
     * Чужое желание — 404, чтобы не раскрывать существование.
     */
    public function show(Request $request, Wish $wish): WishResource
    {
        abort_unless($request->user()->can('view', $wish), 404);

        return new WishResource($wish);
    }

    /**
     * Обновление желания. Только владелец (WishPolicy::update).
     */
    public function update(UpdateWishRequest $request, Wish $wish): WishResource
    {
        abort_unless($request->user()->can('update', $wish), 404);

        $validated = $request->validated();
        // Поле отсутствует → набор не трогаем; присутствует
        // (включая []) → полная замена упорядоченного набора.
        $imagesProvided = array_key_exists('images', $validated);
        $images = $validated['images'] ?? [];
        unset($validated['images']);

        /** @var list<string> $removedImageIds */
        $removedImageIds = [];
        DB::transaction(function () use (
            $wish,
            $validated,
            $imagesProvided,
            $images,
            &$removedImageIds,
        ) {
            $wish->update($validated);

            if (! $imagesProvided) {
                return;
            }
            $removedImageIds = $this->replaceImages(
                $wish,
                $images,
                $validated['image_url'] ?? null,
            );
        });

        // Media-объекты удалённых изображений — через retryable job:
        // сбой S3 не должен ломать обновление желания.
        if ($removedImageIds !== []) {
            DeleteMediaClientObjects::dispatch(
                'wish',
                $removedImageIds,
                $request->user()->id,
            );
        }

        $wish->load('images');

        return new WishResource($wish);
    }

    /**
     * Полная замена доп.изображений желания упорядоченным набором.
     *
     * Элемент с `id`, принадлежащим ЭТОМУ желанию, обновляется;
     * без id или с чужим id — создаётся новая строка (клиентский
     * id применяется только свободный). Порядок = индекс массива
     * → `sort_order` 1..N.
     *
     * @param  array<int, array{id?: ?string, url: string}>  $images
     * @param  string|null  $primaryUrl  Новый `image_url` желания:
     *                                   удалённое изображение, ставшее primary, не чистится —
     *                                   его S3-объект теперь обслуживает обложку.
     * @return list<string> id удалённых изображений (для cleanup S3)
     */
    private function replaceImages(
        Wish $wish,
        array $images,
        ?string $primaryUrl = null,
    ): array {
        $incomingIds = collect($images)->pluck('id')->filter()->all();
        $existingIds = $wish->images()->pluck('id')->all();
        $ownIncoming = array_intersect($incomingIds, $existingIds);

        $removedIds = array_values(array_diff($existingIds, $ownIncoming));
        if ($removedIds !== []) {
            // Изображение, продвинутое в primary (его URL теперь
            // в image_url), из cleanup исключаем — иначе удалим
            // объект, на который ссылается обложка.
            $promotedIds = $primaryUrl === null
                ? []
                : $wish->images()
                    ->whereIn('id', $removedIds)
                    ->where('url', $primaryUrl)
                    ->pluck('id')
                    ->all();
            $wish->images()->whereIn('id', $removedIds)->delete();
            $removedIds = array_values(array_diff($removedIds, $promotedIds));
        }

        foreach ($images as $index => $image) {
            $id = $image['id'] ?? null;
            $owned = $id !== null && in_array($id, $ownIncoming, true);
            if ($owned) {
                $wish->images()->whereKey($id)->update([
                    'url' => $image['url'],
                    'sort_order' => $index + 1,
                ]);
            } else {
                $wish->images()->create([
                    // Чужой/занятый id не доверяем — серверный UUID.
                    'id' => WishImage::whereKey($id)->doesntExist() ? $id : null,
                    'url' => $image['url'],
                    'sort_order' => $index + 1,
                ]);
            }
        }

        return $removedIds;
    }

    /**
     * Удаление желания. Только владелец (WishPolicy::delete). 204.
     */
    public function destroy(Request $request, Wish $wish): JsonResponse
    {
        abort_unless($request->user()->can('delete', $wish), 404);

        $wish->delete();

        return response()->json(null, 204);
    }
}
