<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\StoreWishListRequest;
use App\Http\Requests\Api\UpdateWishListRequest;
use App\Http\Resources\WishListResource;
use App\Models\WishList;
use Illuminate\Database\QueryException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class WishListController extends Controller
{
    /**
     * Списки желаний текущего пользователя, created_at DESC —
     * как во frontend (новые первые). Soft-deleted не попадают
     * в snapshot (scope SoftDeletes).
     */
    public function index(Request $request): AnonymousResourceCollection
    {
        $lists = $request->user()
            ->wishLists()
            ->latest('created_at')
            ->get();

        return WishListResource::collection($lists);
    }

    /**
     * Создание списка. owner_id — auth()->id(), из request
     * не принимается. id — клиентский UUID: повторная отправка
     * с той же identity получает 409 (lost-response retry
     * reconcile'ится клиентом через GET). 201.
     */
    public function store(StoreWishListRequest $request): JsonResponse
    {
        $id = $request->validated('id');
        abort_if(
            $id !== null && WishList::whereKey($id)->exists(),
            409,
            'Resource already exists.'
        );

        try {
            $list = $request->user()->wishLists()->create($request->validated());
        } catch (QueryException $e) {
            abort_if($this->isDuplicateKeyViolation($e), 409, 'Resource already exists.');

            throw $e;
        }

        return (new WishListResource($list))
            ->toResponse($request)
            ->setStatusCode(201);
    }

    /**
     * Список. Только владелец (WishListPolicy::view); чужой → 404.
     */
    public function show(Request $request, WishList $wishList): WishListResource
    {
        abort_unless($request->user()->can('view', $wishList), 404);

        return new WishListResource($wishList);
    }

    /**
     * Переименование. Только title — owner/created_at отсутствуют
     * в Form Request. Только владелец.
     */
    public function update(UpdateWishListRequest $request, WishList $wishList): WishListResource
    {
        abort_unless($request->user()->can('update', $wishList), 404);

        $wishList->update($request->validated());

        return new WishListResource($wishList);
    }

    /**
     * Удаление списка. Только владелец. Soft delete — желания
     * списка не затрагиваются (связь wish↔list живёт на клиенте).
     * 204.
     */
    public function destroy(Request $request, WishList $wishList): JsonResponse
    {
        abort_unless($request->user()->can('delete', $wishList), 404);

        // Желания не удаляются — разгруппировываются (soft-delete
        // не вызывает FK ON DELETE SET NULL, делаем это явно).
        $wishList->wishes()->update(['list_id' => null]);
        $wishList->delete();

        return response()->json(null, 204);
    }
}
