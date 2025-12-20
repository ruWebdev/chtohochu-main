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
            return $this->redirectToApp($token, 'not_found');
        }

        if ($shareToken->isRevoked()) {
            return $this->redirectToApp($token, 'revoked');
        }

        if (!$shareToken->isActive()) {
            return $this->redirectToApp($token, 'expired');
        }

        $entity = $shareToken->getEntity();

        if (!$entity) {
            return $this->redirectToApp($token, 'entity_deleted');
        }

        // Все проверки прошли — редиректим на SPA/веб-обёртку с токеном
        return $this->redirectToApp($shareToken->share_token);
    }

    /**
     * Выполняет redirect на SPA/веб-обёртку, передавая токен и, опционально, код ошибки.
     *
     * Никогда не отдаёт JSON, чтобы пользователь не видел "сырой" ответ.
     */
    private function redirectToApp(string $token, ?string $error = null)
    {
        // Базовый URL SPA / веб-приложения. Обычно совпадает с sharing.share_base_url.
        $baseUrl = rtrim((string) config('sharing.share_base_url'), '/');

        $query = [
            'sharedToken' => $token,
        ];

        if ($error !== null) {
            $query['error'] = $error;
        }

        $url = $baseUrl . '/?' . http_build_query($query);

        return redirect()->away($url, 302);
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
