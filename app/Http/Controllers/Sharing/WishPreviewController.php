<?php

namespace App\Http\Controllers\Sharing;

use App\Http\Controllers\Controller;
use App\Models\Wishlist;
use App\Models\Wish;
use Illuminate\Http\Request;

class WishPreviewController extends Controller
{
    public function __invoke(Request $request, Wish $wish)
    {
        if ($wish->visibility !== Wish::VISIBILITY_PUBLIC) {
            abort(404);
        }

        $wish->load(['owner', 'wishlist']);

        $scheme = (string) config('sharing.deep_link_scheme', 'chtohochu');
        $appStoreUrl = (string) config('sharing.app_store_url');
        $playStoreUrl = (string) config('sharing.play_store_url');

        $images = [];

        if (is_array($wish->images)) {
            $images = $wish->images;
        }

        $price = $wish->desired_price !== null ? (string) $wish->desired_price : null;

        $wishlist = $wish->wishlist;

        return response()->json([
            'data' => [
                'type' => 'wish',
                'id' => $wish->id,
                'name' => $wish->name,
                'description' => $wish->description,
                'images' => $images,
                'price' => $price,
                'link' => $wish->url,
                'owner' => [
                    'id' => $wish->owner?->id,
                    'name' => $wish->owner?->name,
                    'avatar' => $wish->owner?->avatar,
                ],
                'wishlist' => $wishlist ? [
                    'id' => $wishlist->id,
                    'name' => $wishlist->name,
                ] : null,
                'deeplink' => $scheme . '://wish/' . $wish->id,
                'app_store_url' => $appStoreUrl,
                'play_store_url' => $playStoreUrl,
            ],
        ]);
    }
}
