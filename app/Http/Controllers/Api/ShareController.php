<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ShoppingList;
use App\Models\Wishlist;
use App\Models\Wish;
use Illuminate\Http\Request;

class ShareController extends Controller
{
    public function wishlist(Request $request, Wishlist $wishlist)
    {
        $this->authorize('view', $wishlist);

        $data = $request->validate([
            'access_type' => ['sometimes', 'string', 'in:public,by_link,friends'],
        ]);

        $accessType = $data['access_type'] ?? 'public';

        $path = 'wishlist/' . $wishlist->id;

        return response()->json([
            'data' => $this->buildSharePayload($path, 'wishlist', $accessType),
        ]);
    }

    public function wish(Request $request, Wishlist $wishlist, Wish $wish)
    {
        $this->authorize('view', $wishlist);

        if ($wish->wishlist_id !== $wishlist->id) {
            abort(404);
        }

        $path = 'wish/' . $wish->id;

        return response()->json([
            'data' => $this->buildSharePayload($path, 'wish', 'public'),
        ]);
    }

    public function shoppingList(Request $request, ShoppingList $shoppingList)
    {
        $this->authorize('view', $shoppingList);

        $data = $request->validate([
            'access_type' => ['sometimes', 'string', 'in:public,by_link,friends'],
            'role' => ['sometimes', 'string', 'in:viewer,editor'],
        ]);

        $accessType = $data['access_type'] ?? 'public';

        $path = 'shopping-list/' . $shoppingList->id;

        return response()->json([
            'data' => $this->buildSharePayload($path, 'shopping-list', $accessType),
        ]);
    }

    public function me(Request $request)
    {
        $user = $request->user();

        $path = 'user/' . $user->username;

        return response()->json([
            'data' => $this->buildSharePayload($path, 'user', 'public'),
        ]);
    }

    public function app(Request $request)
    {
        $path = 'app';

        $base = $this->buildSharePayload($path, 'app', 'public');

        return response()->json([
            'data' => array_merge($base, [
                'app_store_url' => config('sharing.app_store_url'),
                'play_store_url' => config('sharing.play_store_url'),
            ]),
        ]);
    }

    private function buildSharePayload(string $path, string $type, string $accessType): array
    {
        $baseUrl = rtrim((string) config('sharing.share_base_url'), '/');
        $scheme = (string) config('sharing.deep_link_scheme', 'chtohochu');

        $normalizedPath = ltrim($path, '/');

        $url = $baseUrl . '/' . $normalizedPath;
        $deeplink = $scheme . '://' . $normalizedPath;

        $qrUrl = route('api.qr.generate', [
            'type' => $type,
            'id' => $type === 'app' ? null : basename($normalizedPath),
        ]);

        return [
            'url' => $url,
            'deeplink' => $deeplink,
            'qr_code_url' => $qrUrl,
            'expires_at' => null,
        ];
    }
}
