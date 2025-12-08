<?php

namespace App\Http\Controllers\Sharing;

use App\Http\Controllers\Controller;
use App\Models\Wishlist;
use App\Models\Wish;
use Illuminate\Http\Request;

class WishlistPreviewController extends Controller
{
    public function __invoke(Request $request, Wishlist $wishlist)
    {
        if ($wishlist->visibility !== Wishlist::VISIBILITY_PUBLIC) {
            abort(404);
        }

        $wishlist->load([
            'owner',
            'wishes' => function ($query) {
                $query->orderBy('created_at', 'desc')->limit(5);
            },
        ]);

        $scheme = (string) config('sharing.deep_link_scheme', 'chtohochu');
        $appStoreUrl = (string) config('sharing.app_store_url');
        $playStoreUrl = (string) config('sharing.play_store_url');

        $wishes = $wishlist->wishes->map(function (Wish $wish) {
            $image = null;

            if (is_array($wish->images) && $wish->images !== []) {
                $image = $wish->images[0];
            }

            return [
                'id' => $wish->id,
                'name' => $wish->name,
                'image' => $image,
                'price_range' => $this->formatPriceRange($wish),
            ];
        })->values();

        return response()->json([
            'data' => [
                'type' => 'wishlist',
                'id' => $wishlist->id,
                'title' => $wishlist->name,
                'description' => $wishlist->description,
                'visibility' => $wishlist->visibility,
                'owner' => [
                    'id' => $wishlist->owner?->id,
                    'name' => $wishlist->owner?->name,
                    'avatar' => $wishlist->owner?->avatar,
                ],
                'wishes' => $wishes,
                'wishes_count' => $wishlist->wishes->count(),
                'deeplink' => $scheme . '://wishlist/' . $wishlist->id,
                'app_store_url' => $appStoreUrl,
                'play_store_url' => $playStoreUrl,
            ],
        ]);
    }

    private function formatPriceRange(Wish $wish): ?string
    {
        $desired = $wish->desired_price;
        $min = $wish->price_min;
        $max = $wish->price_max;

        if ($desired !== null) {
            return (string) $desired;
        }

        if ($min !== null && $max !== null) {
            return (string) $min . '-' . (string) $max;
        }

        if ($min !== null) {
            return (string) $min . '+';
        }

        if ($max !== null) {
            return '0-' . (string) $max;
        }

        return null;
    }
}
