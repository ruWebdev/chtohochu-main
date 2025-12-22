<?php

namespace App\Http\Controllers\Sharing;

use App\Http\Controllers\Controller;
use App\Models\ShareToken;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Inertia\Inertia;

/**
 * Контроллер для отображения превью по share-токену.
 * Обрабатывает переходы по ссылкам формата /s/{token}.
 */
class ShareTokenPreviewController extends Controller
{
    public function __invoke(Request $request, string $token)
    {
        $shareToken = ShareToken::byToken($token)->first();

        $status = 'ok';

        if (!$shareToken) {
            $status = 'not_found';
        } elseif ($shareToken->isRevoked()) {
            $status = 'revoked';
        } elseif (!$shareToken->isActive()) {
            $status = 'expired';
        }

        $entity = null;

        if ($status === 'ok') {
            $entity = $shareToken->getEntity();

            if (!$entity) {
                $status = 'entity_deleted';
            }
        }

        $entityType = $shareToken?->entity_type;

        $wishlist = null;
        $shoppingList = null;
        $wish = null;

        if ($status === 'ok' && $entity) {
            if ($entityType === ShareToken::ENTITY_WISHLIST) {
                $wishlist = $this->buildWishlistData($entity);
            } elseif ($entityType === ShareToken::ENTITY_SHOPPING_LIST) {
                $shoppingList = $this->buildShoppingListData($entity);
            } elseif ($entityType === ShareToken::ENTITY_WISH) {
                $wish = $this->buildWishData($entity);
            }
        }

        $scheme = (string) config('sharing.deep_link_scheme', 'chtohochu');
        $appStoreUrl = (string) config('sharing.app_store_url');
        $playStoreUrl = (string) config('sharing.play_store_url');

        return Inertia::render('Sharing/UniversalListViewer', [
            'status' => $status,
            'entity_type' => $entityType,
            'token' => $token,
            'wishlist' => $wishlist,
            'shopping_list' => $shoppingList,
            'wish' => $wish,
            'owner' => $entity && method_exists($entity, 'owner') ? [
                'name' => optional($entity->owner)->name,
                'avatar' => optional($entity->owner)->avatar_url,
            ] : null,
            'deeplink' => $scheme . '://s/' . $token,
            'app_store_url' => $appStoreUrl,
            'play_store_url' => $playStoreUrl,
        ]);
    }

    private function buildWishData($wish): array
    {
        return [
            'id' => $wish->id,
            'name' => $wish->name,
            'description' => $wish->description,
            'images' => $wish->getFullImageUrls(),
            'desired_price' => $wish->desired_price,
            'price_min' => $wish->price_min,
            'price_max' => $wish->price_max,
            'url' => $wish->url,
            'status' => $wish->status,
            'visibility' => $wish->visibility,
        ];
    }

    private function buildWishlistData($wishlist): array
    {
        $wishlist->load(['wishes' => function ($query) {
            $query->orderBy('created_at', 'desc')->limit(5);
        }]);

        $wishes = $wishlist->wishes->map(function ($wish) {
            $image = null;
            if (is_array($wish->images) && $wish->images !== []) {
                $image = $wish->images[0];
            }

            return [
                'id' => $wish->id,
                'name' => $wish->name,
                'image' => $image,
            ];
        })->values();

        return [
            'id' => $wishlist->id,
            'name' => $wishlist->name,
            'description' => $wishlist->description,
            'visibility' => $wishlist->visibility,
            'wishes_count' => $wishlist->wishes()->count(),
            'wishes_preview' => $wishes,
            'avatar' => $wishlist->avatar ? Storage::url($wishlist->avatar) : null,
        ];
    }

    private function buildShoppingListData($shoppingList): array
    {
        $shoppingList->load(['items' => function ($query) {
            $query->orderBy('created_at', 'desc')->limit(5);
        }]);

        $items = $shoppingList->items->map(function ($item) {
            return [
                'id' => $item->id,
                'name' => $item->name,
                'is_purchased' => $item->is_purchased,
            ];
        })->values();

        $totalItems = $shoppingList->items()->count();
        $purchasedItems = $shoppingList->items()->where('is_purchased', true)->count();

        return [
            'id' => $shoppingList->id,
            'name' => $shoppingList->name,
            'description' => $shoppingList->description,
            'is_shared' => $shoppingList->is_shared,
            'items_count' => $totalItems,
            'purchased_count' => $purchasedItems,
            'items_preview' => $items,
            'avatar' => $shoppingList->avatar ? Storage::url($shoppingList->avatar) : null,
        ];
    }
}
