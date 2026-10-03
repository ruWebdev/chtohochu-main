<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\StoreShoppingItemRequest;
use App\Http\Requests\Api\UpdateShoppingItemRequest;
use App\Http\Resources\ShoppingItemResource;
use App\Models\ShoppingItem;
use App\Models\ShoppingList;
use Illuminate\Database\QueryException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ShoppingItemController extends Controller
{
    /**
     * Добавление позиции в список из URL. Только владельцу
     * списка (ShoppingItemPolicy::create по parent list).
     * quantity default 1, is_checked — false из БД. 201.
     */
    public function store(StoreShoppingItemRequest $request, ShoppingList $shoppingList): JsonResponse
    {
        abort_unless($request->user()->can('create', [ShoppingItem::class, $shoppingList]), 404);

        $id = $request->validated('id');
        abort_if(
            $id !== null && ShoppingItem::whereKey($id)->exists(),
            409,
            'Resource already exists.'
        );

        try {
            $item = $shoppingList->items()->create($request->validated());
        } catch (QueryException $e) {
            abort_if($this->isDuplicateKeyViolation($e), 409, 'Resource already exists.');

            throw $e;
        }

        // DB-defaults (quantity=1, is_checked=false) —
        // перечитываем, чтобы отдать фактические значения.
        $item->refresh();

        return (new ShoppingItemResource($item))
            ->toResponse($request)
            ->setStatusCode(201);
    }

    /**
     * Атомарное обновление позиции: title/quantity/is_checked.
     * list_id поменять нельзя. Только владелец списка.
     */
    public function update(UpdateShoppingItemRequest $request, ShoppingItem $shoppingItem): ShoppingItemResource
    {
        abort_unless($request->user()->can('update', $shoppingItem), 404);

        $shoppingItem->update($request->validated());

        return new ShoppingItemResource($shoppingItem);
    }

    /**
     * Удаление позиции. Только владелец списка. 204.
     */
    public function destroy(Request $request, ShoppingItem $shoppingItem): JsonResponse
    {
        abort_unless($request->user()->can('delete', $shoppingItem), 404);

        $shoppingItem->delete();

        return response()->json(null, 204);
    }
}
