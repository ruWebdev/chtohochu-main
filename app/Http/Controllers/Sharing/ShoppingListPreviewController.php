<?php

namespace App\Http\Controllers\Sharing;

use App\Http\Controllers\Controller;
use App\Models\ShoppingList;
use Illuminate\Http\Request;

class ShoppingListPreviewController extends Controller
{
    public function __invoke(Request $request, ShoppingList $shoppingList)
    {
        if (! $shoppingList->is_shared) {
            abort(404);
        }

        $shoppingList->load(['owner', 'items']);

        $scheme = (string) config('sharing.deep_link_scheme', 'chtohochu');
        $appStoreUrl = (string) config('sharing.app_store_url');
        $playStoreUrl = (string) config('sharing.play_store_url');

        $itemsCount = $shoppingList->items->count();
        $completedCount = $shoppingList->items->where('is_purchased', true)->count();

        return response()->json([
            'data' => [
                'type' => 'shopping_list',
                'id' => $shoppingList->id,
                'name' => $shoppingList->name,
                'items_count' => $itemsCount,
                'completed_count' => $completedCount,
                'owner' => [
                    'id' => $shoppingList->owner?->id,
                    'name' => $shoppingList->owner?->name,
                    'avatar' => $shoppingList->owner?->avatar,
                ],
                'access' => $shoppingList->is_shared ? 'by_link' : 'private',
                'can_edit' => false,
                'deeplink' => $scheme . '://shopping-list/' . $shoppingList->id,
                'app_store_url' => $appStoreUrl,
                'play_store_url' => $playStoreUrl,
            ],
        ]);
    }
}
