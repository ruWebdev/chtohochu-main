<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\WishLikeResource;
use App\Models\Wish;
use App\Models\WishLike;
use Illuminate\Http\Request;

/**
 * Контроллер лайков желаний.
 */
class WishLikeController extends Controller
{
    /**
     * Получить лайки желания.
     */
    public function index(Request $request, Wish $wish)
    {
        $likes = $wish->likes()
            ->with('user')
            ->orderBy('created_at', 'desc')
            ->get();

        return WishLikeResource::collection($likes);
    }

    /**
     * Поставить лайк желанию.
     */
    public function store(Request $request, Wish $wish)
    {
        $user = $request->user();

        // Проверяем, не лайкнул ли уже
        $existingLike = WishLike::where('wish_id', $wish->id)
            ->where('user_id', $user->id)
            ->first();

        if ($existingLike) {
            return response()->json([
                'message' => __('wishlist.already_liked'),
                'data' => [
                    'likes_count' => $wish->likes()->count(),
                    'is_liked_by_me' => true,
                ],
            ]);
        }

        WishLike::create([
            'wish_id' => $wish->id,
            'user_id' => $user->id,
        ]);

        return response()->json([
            'message' => __('wishlist.liked'),
            'data' => [
                'likes_count' => $wish->likes()->count(),
                'is_liked_by_me' => true,
            ],
        ], 201);
    }

    /**
     * Убрать лайк с желания.
     */
    public function destroy(Request $request, Wish $wish)
    {
        $user = $request->user();

        $deleted = WishLike::where('wish_id', $wish->id)
            ->where('user_id', $user->id)
            ->delete();

        return response()->json([
            'message' => $deleted ? __('wishlist.unliked') : __('wishlist.not_liked'),
            'data' => [
                'likes_count' => $wish->likes()->count(),
                'is_liked_by_me' => false,
            ],
        ]);
    }

    /**
     * Переключить лайк (toggle).
     */
    public function toggle(Request $request, Wish $wish)
    {
        $user = $request->user();

        $existingLike = WishLike::where('wish_id', $wish->id)
            ->where('user_id', $user->id)
            ->first();

        if ($existingLike) {
            $existingLike->delete();
            $isLiked = false;
            $message = __('wishlist.unliked');
        } else {
            WishLike::create([
                'wish_id' => $wish->id,
                'user_id' => $user->id,
            ]);
            $isLiked = true;
            $message = __('wishlist.liked');
        }

        return response()->json([
            'message' => $message,
            'data' => [
                'likes_count' => $wish->likes()->count(),
                'is_liked_by_me' => $isLiked,
            ],
        ]);
    }
}
