<?php

namespace App\Http\Controllers\Sharing;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\Wishlist;
use Illuminate\Http\Request;

class UserPreviewController extends Controller
{
    public function __invoke(Request $request, string $username)
    {
        $user = User::query()
            ->where('username', $username)
            ->firstOrFail();

        $publicWishlistsCount = Wishlist::query()
            ->where('owner_id', $user->id)
            ->where('visibility', Wishlist::VISIBILITY_PUBLIC)
            ->count();

        $scheme = (string) config('sharing.deep_link_scheme', 'chtohochu');
        $appStoreUrl = (string) config('sharing.app_store_url');
        $playStoreUrl = (string) config('sharing.play_store_url');

        return response()->json([
            'data' => [
                'type' => 'user',
                'id' => $user->id,
                'username' => $user->username,
                'name' => $user->name,
                'avatar' => $user->avatar,
                'about' => $user->about,
                'public_wishlists_count' => $publicWishlistsCount,
                'deeplink' => $scheme . '://user/' . $user->username,
                'app_store_url' => $appStoreUrl,
                'play_store_url' => $playStoreUrl,
            ],
        ]);
    }
}
