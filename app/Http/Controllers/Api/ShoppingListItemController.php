<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Shopping\StoreShoppingListItemRequest;
use App\Http\Requests\Shopping\UpdateShoppingListItemRequest;
use App\Models\ShoppingList;
use App\Models\ShoppingListItem;
use Illuminate\Http\Request;
use App\Http\Resources\ShoppingListItemResource;

class ShoppingListItemController extends Controller
{
    /**
     * Список пунктов конкретного списка покупок.
     */
    public function index(Request $request, ShoppingList $shoppingList)
    {
        $this->authorize('view', $shoppingList);

        $items = $shoppingList->items()
            ->with(['assignedUser', 'completedBy'])
            ->orderBy('sort_index')
            ->orderBy('created_at')
            ->get();

        return ShoppingListItemResource::collection($items);
    }
    /**
     * Добавление пункта в список покупок.
     */
    public function store(StoreShoppingListItemRequest $request, ShoppingList $shoppingList)
    {
        $this->authorize('update', $shoppingList);

        $data = $request->validated();
        $data['shopping_list_id'] = $shoppingList->id;

        $item = ShoppingListItem::query()->create($data);
        $item->load(['assignedUser', 'completedBy']);

        return response()->json([
            'message' => __('shopping.item_created'),
            'data' => new ShoppingListItemResource($item),
        ], 201);
    }

    /**
     * Обновление пункта списка покупок.
     */
    public function update(UpdateShoppingListItemRequest $request, ShoppingList $shoppingList, ShoppingListItem $item)
    {
        $this->authorize('update', $shoppingList);

        if ($item->shopping_list_id !== $shoppingList->id) {
            abort(404);
        }

        $item->fill($request->validated());
        $item->save();

        $item->load(['assignedUser', 'completedBy']);

        return response()->json([
            'message' => __('shopping.item_updated'),
            'data' => new ShoppingListItemResource($item),
        ]);
    }

    /**
     * Удаление пункта списка покупок.
     */
    public function destroy(Request $request, ShoppingList $shoppingList, ShoppingListItem $item)
    {
        $this->authorize('update', $shoppingList);

        if ($item->shopping_list_id !== $shoppingList->id) {
            abort(404);
        }

        $item->delete();

        return response()->json([
            'message' => __('shopping.item_deleted'),
        ]);
    }
}
