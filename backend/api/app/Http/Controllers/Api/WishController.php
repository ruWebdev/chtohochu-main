<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\StoreWishRequest;
use App\Http\Requests\Api\UpdateWishRequest;
use App\Http\Resources\WishResource;
use App\Models\Wish;
use Illuminate\Database\QueryException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

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

        try {
            $wish = $request->user()->wishes()->create($request->validated());
        } catch (QueryException $e) {
            // Гонка между exists() и insert — тот же 409.
            abort_if($this->isDuplicateKeyViolation($e), 409, 'Resource already exists.');

            throw $e;
        }

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

        $wish->update($request->validated());

        return new WishResource($wish);
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
