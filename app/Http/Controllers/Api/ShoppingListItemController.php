<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Shopping\StoreShoppingListItemRequest;
use App\Http\Requests\Shopping\UpdateShoppingListItemRequest;
use App\Http\Requests\Shopping\UploadShoppingListItemImageRequest;
use App\Models\ShoppingList;
use App\Models\ShoppingListItem;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use App\Http\Resources\ShoppingListItemResource;
use Intervention\Image\ImageManager;
use Intervention\Image\Drivers\Imagick\Driver as ImagickDriver;

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

    /**
     * Загрузка и обработка изображения для пункта списка покупок.
     * Генерирует три webp-версии: full (1200px), preview (300px), thumbnail (80px).
     */
    public function uploadImage(
        UploadShoppingListItemImageRequest $request,
        ShoppingList $shoppingList,
        ShoppingListItem $item
    ) {
        $this->authorize('update', $shoppingList);

        if ($item->shopping_list_id !== $shoppingList->id) {
            abort(404);
        }

        $file = $request->file('image');

        $manager = new ImageManager(new ImagickDriver());
        $image = $manager->read($file->getPathname());

        $basePath = 'shopping-items/' . $item->id;

        // Удаляем предыдущие файлы, если они были
        $pathsToDelete = array_filter([
            $item->image_full_url,
            $item->image_preview_url,
            $item->image_thumb_url,
        ]);

        if (!empty($pathsToDelete)) {
            Storage::disk('public')->delete($pathsToDelete);
        }

        // Генерация трёх размеров (по длинной стороне)
        // Важно: scaleDown мутирует объект, поэтому клонируем перед каждым ресайзом
        $full = (clone $image)->scaleDown(1200, 1200);
        $preview = (clone $image)->scaleDown(300, 300);
        $thumb = (clone $image)->scaleDown(80, 80);

        $fullPath = $basePath . '/full.webp';
        $previewPath = $basePath . '/preview.webp';
        $thumbPath = $basePath . '/thumb.webp';

        Storage::disk('public')->put($fullPath, (string) $full->toWebp(80));
        Storage::disk('public')->put($previewPath, (string) $preview->toWebp(80));
        Storage::disk('public')->put($thumbPath, (string) $thumb->toWebp(80));

        $item->image_full_url = $fullPath;
        $item->image_preview_url = $previewPath;
        $item->image_thumb_url = $thumbPath;
        // Для обратной совместимости заполняем плоское поле превью-версией
        $item->image_url = $previewPath;
        $item->save();

        $item->load(['assignedUser', 'completedBy']);

        return response()->json([
            'message' => __('shopping.item_updated'),
            'data' => new ShoppingListItemResource($item),
        ]);
    }
}
