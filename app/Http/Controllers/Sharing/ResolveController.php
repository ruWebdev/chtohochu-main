<?php

namespace App\Http\Controllers\Sharing;

use App\Http\Controllers\Controller;
use App\Models\ShoppingList;
use App\Models\Wishlist;
use App\Models\Wish;
use App\Models\User;
use Illuminate\Http\Request;

class ResolveController extends Controller
{
    public function __invoke(Request $request)
    {
        $path = trim((string) $request->query('path', ''), '/');

        if ($path === '') {
            abort(404);
        }

        [$first, $second] = array_pad(explode('/', $path, 2), 2, null);

        $scheme = (string) config('sharing.deep_link_scheme', 'chtohochu');
        $baseUrl = rtrim((string) config('sharing.share_base_url'), '/');

        switch ($first) {
            case 'app':
                return response()->json([
                    'data' => [
                        'type' => 'app',
                        'id' => null,
                        'deeplink' => $scheme . '://app',
                        'fallback' => $baseUrl . '/app',
                        'access' => 'public',
                        'preview' => null,
                    ],
                ]);
            case 'wishlist':
                if ($second === null) {
                    abort(404);
                }

                $wishlist = Wishlist::query()
                    ->with(['owner'])
                    ->findOrFail($second);

                $access = $wishlist->visibility === Wishlist::VISIBILITY_PUBLIC ? 'public' : 'private';

                $preview = null;

                if ($access === 'public') {
                    $preview = [
                        'title' => $wishlist->name,
                        'description' => $wishlist->description,
                        'image' => $wishlist->avatar,
                        'owner' => [
                            'name' => $wishlist->owner?->name,
                            'avatar' => $wishlist->owner?->avatar,
                        ],
                        'items_count' => $wishlist->wishes()->count(),
                    ];
                }

                return response()->json([
                    'data' => [
                        'type' => 'wishlist',
                        'id' => $wishlist->id,
                        'deeplink' => $scheme . '://wishlist/' . $wishlist->id,
                        'fallback' => $baseUrl . '/wishlist/' . $wishlist->id,
                        'access' => $access,
                        'preview' => $preview,
                    ],
                ]);
            case 'wish':
                if ($second === null) {
                    abort(404);
                }

                $wish = Wish::query()
                    ->with(['owner'])
                    ->findOrFail($second);

                $access = $wish->visibility === Wish::VISIBILITY_PUBLIC ? 'public' : 'private';

                $preview = null;

                if ($access === 'public') {
                    $preview = [
                        'title' => $wish->name,
                        'description' => $wish->description,
                        'image' => $wish->images[0] ?? null,
                        'owner' => [
                            'name' => $wish->owner?->name,
                            'avatar' => $wish->owner?->avatar,
                        ],
                        'items_count' => null,
                    ];
                }

                return response()->json([
                    'data' => [
                        'type' => 'wish',
                        'id' => $wish->id,
                        'deeplink' => $scheme . '://wish/' . $wish->id,
                        'fallback' => $baseUrl . '/wish/' . $wish->id,
                        'access' => $access,
                        'preview' => $preview,
                    ],
                ]);
            case 'shopping-list':
                if ($second === null) {
                    abort(404);
                }

                $list = ShoppingList::query()
                    ->with(['owner'])
                    ->findOrFail($second);

                $access = $list->is_shared ? 'public' : 'private';

                $preview = null;

                if ($access === 'public') {
                    $preview = [
                        'title' => $list->name,
                        'description' => $list->description,
                        'image' => $list->avatar,
                        'owner' => [
                            'name' => $list->owner?->name,
                            'avatar' => $list->owner?->avatar,
                        ],
                        'items_count' => $list->items()->count(),
                    ];
                }

                return response()->json([
                    'data' => [
                        'type' => 'shopping_list',
                        'id' => $list->id,
                        'deeplink' => $scheme . '://shopping-list/' . $list->id,
                        'fallback' => $baseUrl . '/shopping-list/' . $list->id,
                        'access' => $access,
                        'preview' => $preview,
                    ],
                ]);
            case 'user':
                if ($second === null) {
                    abort(404);
                }

                $user = User::query()
                    ->where('username', $second)
                    ->firstOrFail();

                $preview = [
                    'title' => $user->name,
                    'description' => $user->about,
                    'image' => $user->avatar,
                    'owner' => null,
                    'items_count' => null,
                ];

                return response()->json([
                    'data' => [
                        'type' => 'user',
                        'id' => $user->id,
                        'deeplink' => $scheme . '://user/' . $user->username,
                        'fallback' => $baseUrl . '/user/' . $user->username,
                        'access' => 'public',
                        'preview' => $preview,
                    ],
                ]);
            default:
                abort(404);
        }
    }
}
