<?php

namespace App\Http\Controllers\Api;

use App\Events\ShoppingListEvent;
use App\Http\Controllers\Controller;
use App\Http\Requests\Api\StoreShoppingItemRequest;
use App\Http\Requests\Api\UpdateShoppingItemRequest;
use App\Http\Resources\ShoppingItemResource;
use App\Models\ShoppingItem;
use App\Models\ShoppingList;
use Illuminate\Database\QueryException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class ShoppingItemController extends Controller
{
    /**
     * Добавление позиции в список из URL. Владельцу и участникам
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
            $item = DB::transaction(function () use ($request, $shoppingList) {
                $item = $shoppingList->items()->create($request->validated());
                $item->bumpRevision();

                return $item;
            });
        } catch (QueryException $e) {
            abort_if($this->isDuplicateKeyViolation($e), 409, 'Resource already exists.');

            throw $e;
        }

        // DB-defaults (quantity=1, is_checked=false) —
        // перечитываем, чтобы отдать фактические значения.
        $item->refresh();

        event(ShoppingListEvent::forItem(
            $shoppingList,
            $item,
            'shopping_list.item.created',
            (new ShoppingItemResource($item))->resolve(),
            $request->user()->id,
        ));

        return (new ShoppingItemResource($item))
            ->toResponse($request)
            ->setStatusCode(201);
    }

    /**
     * Атомарное обновление позиции: title/quantity/is_checked.
     * list_id поменять нельзя. Участникам списка.
     *
     * `is_checked` проходит тем же update — отдельного endpoint
     * для «куплено» нет; realtime-тип checked/unchecked выбирается
     * по флагу для точности контракта.
     */
    public function update(UpdateShoppingItemRequest $request, ShoppingItem $shoppingItem): ShoppingItemResource
    {
        abort_unless($request->user()->can('update', $shoppingItem), 404);

        $wasChecked = $shoppingItem->is_checked;
        DB::transaction(function () use ($request, $shoppingItem) {
            $shoppingItem->update($request->validated());
            $shoppingItem->bumpRevision();
        });

        $list = $shoppingItem->list;
        $eventType = $shoppingItem->is_checked === $wasChecked
            ? 'shopping_list.item.updated'
            : ($shoppingItem->is_checked
                ? 'shopping_list.item.checked'
                : 'shopping_list.item.unchecked');

        // Полный snapshot позиции — клиент может применить без
        // дополнительного GET (realtime-events.md §2.2).
        event(ShoppingListEvent::forItem(
            $list,
            $shoppingItem,
            $eventType,
            (new ShoppingItemResource($shoppingItem))->resolve(),
            $request->user()->id,
        ));

        return new ShoppingItemResource($shoppingItem);
    }

    /**
     * Удаление позиции. Участникам списка. 204.
     */
    public function destroy(Request $request, ShoppingItem $shoppingItem): JsonResponse
    {
        abort_unless($request->user()->can('delete', $shoppingItem), 404);

        $list = $shoppingItem->list;
        DB::transaction(function () use ($shoppingItem) {
            $shoppingItem->bumpRevision();
            $shoppingItem->delete();
        });

        event(ShoppingListEvent::forItem(
            $list,
            $shoppingItem,
            'shopping_list.item.deleted',
            ['deleted' => true],
            $request->user()->id,
        ));

        return response()->json(null, 204);
    }
}
