<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\StoreShoppingListRequest;
use App\Http\Requests\Api\UpdateShoppingListRequest;
use App\Http\Resources\ShoppingListResource;
use App\Models\ShoppingList;
use Illuminate\Database\QueryException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class ShoppingListController extends Controller
{
    /**
     * Списки текущего пользователя с items (eager loading,
     * без N+1), created_at DESC — как во frontend (новые первые).
     */
    public function index(Request $request): AnonymousResourceCollection
    {
        $lists = $request->user()
            ->shoppingLists()
            ->with('items')
            ->latest('created_at')
            ->get();

        return ShoppingListResource::collection($lists);
    }

    /**
     * Создание списка. owner_id — auth()->id(), из request
     * не принимается. 201.
     */
    public function store(StoreShoppingListRequest $request): JsonResponse
    {
        $id = $request->validated('id');
        abort_if(
            $id !== null && ShoppingList::whereKey($id)->exists(),
            409,
            'Resource already exists.'
        );

        try {
            $list = $request->user()->shoppingLists()->create($request->validated());
        } catch (QueryException $e) {
            abort_if($this->isDuplicateKeyViolation($e), 409, 'Resource already exists.');

            throw $e;
        }

        $list->setRelation('items', collect());

        return (new ShoppingListResource($list))
            ->toResponse($request)
            ->setStatusCode(201);
    }

    /**
     * Список с items. Только владелец (ShoppingListPolicy::view);
     * чужой → 404.
     */
    public function show(Request $request, ShoppingList $shoppingList): ShoppingListResource
    {
        abort_unless($request->user()->can('view', $shoppingList), 404);

        $shoppingList->load('items');

        return new ShoppingListResource($shoppingList);
    }

    /**
     * Переименование. Только title — owner/items/created_at
     * отсутствуют в Form Request. Только владелец.
     */
    public function update(UpdateShoppingListRequest $request, ShoppingList $shoppingList): ShoppingListResource
    {
        abort_unless($request->user()->can('update', $shoppingList), 404);

        $shoppingList->update($request->validated());
        $shoppingList->load('items');

        return new ShoppingListResource($shoppingList);
    }

    /**
     * Удаление списка. Только владелец. Items удаляются
     * каскадом FK на уровне БД. 204.
     */
    public function destroy(Request $request, ShoppingList $shoppingList): JsonResponse
    {
        abort_unless($request->user()->can('delete', $shoppingList), 404);

        $shoppingList->delete();

        return response()->json(null, 204);
    }
}
