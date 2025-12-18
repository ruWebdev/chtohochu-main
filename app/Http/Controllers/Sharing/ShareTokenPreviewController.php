<?php

namespace App\Http\Controllers\Sharing;

use App\Http\Controllers\Controller;
use App\Models\ShareToken;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

/**
 * Контроллер для отображения превью по share-токену.
 * Обрабатывает переходы по ссылкам формата /s/{token}.
 */
class ShareTokenPreviewController extends Controller
{
    public function __invoke(Request $request, string $token)
    {
        $shareToken = ShareToken::byToken($token)->first();

        if (!$shareToken) {
            return $this->errorResponse('not_found', 'Ссылка не найдена', 404);
        }

        if ($shareToken->isRevoked()) {
            return $this->errorResponse('revoked', 'Ссылка была отозвана', 410);
        }

        if (!$shareToken->isActive()) {
            return $this->errorResponse('expired', 'Срок действия ссылки истёк', 410);
        }

        $entity = $shareToken->getEntity();

        if (!$entity) {
            return $this->errorResponse('entity_deleted', 'Объект больше недоступен', 410);
        }

        $scheme = (string) config('sharing.deep_link_scheme', 'chtohochu');
        $appStoreUrl = (string) config('sharing.app_store_url');
        $playStoreUrl = (string) config('sharing.play_store_url');

        $response = [
            'type' => $shareToken->entity_type,
            'id' => $shareToken->entity_id,
            'token' => $shareToken->share_token,
            'title' => $shareToken->title,
            'description' => $shareToken->description,
            'preview_image_url' => $shareToken->preview_image_url,
            'owner' => [
                'id' => $entity->owner?->id,
                'name' => $entity->owner?->name,
                'avatar' => $entity->owner?->avatar_url ?? $entity->owner?->avatar,
            ],
            'deeplink' => $scheme . '://s/' . $shareToken->share_token,
            'app_store_url' => $appStoreUrl,
            'play_store_url' => $playStoreUrl,
        ];

        // Добавляем специфичные данные в зависимости от типа сущности
        switch ($shareToken->entity_type) {
            case ShareToken::ENTITY_WISH:
                $response['wish'] = $this->buildWishData($entity);
                break;

            case ShareToken::ENTITY_WISHLIST:
                $response['wishlist'] = $this->buildWishlistData($entity);
                break;

            case ShareToken::ENTITY_SHOPPING_LIST:
                $response['shopping_list'] = $this->buildShoppingListData($entity);
                break;
        }

        return response()->json(['data' => $response]);
    }

    private function errorResponse(string $error, string $message, int $status): \Illuminate\Http\JsonResponse
    {
        $scheme = (string) config('sharing.deep_link_scheme', 'chtohochu');
        $appStoreUrl = (string) config('sharing.app_store_url');
        $playStoreUrl = (string) config('sharing.play_store_url');

        return response()->json([
            'error' => $error,
            'message' => $message,
            'deeplink' => $scheme . '://app',
            'app_store_url' => $appStoreUrl,
            'play_store_url' => $playStoreUrl,
        ], $status);
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
