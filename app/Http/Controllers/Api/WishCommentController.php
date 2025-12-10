<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\WishCommentResource;
use App\Models\Wish;
use App\Models\WishComment;
use App\Models\WishHistory;
use Illuminate\Http\Request;

/**
 * Контроллер комментариев к желаниям.
 */
class WishCommentController extends Controller
{
    /**
     * Получить комментарии к желанию.
     */
    public function index(Request $request, Wish $wish)
    {
        // Проверяем доступ к желанию
        $this->authorizeWishAccess($wish, $request->user());

        $comments = $wish->comments()
            ->with('user')
            ->orderBy('created_at', 'desc')
            ->paginate(20);

        return WishCommentResource::collection($comments);
    }

    /**
     * Создать комментарий к желанию.
     */
    public function store(Request $request, Wish $wish)
    {
        $user = $request->user();

        // Проверяем доступ к желанию
        $this->authorizeWishAccess($wish, $user);

        // Проверяем, разрешены ли комментарии
        if (!($wish->allow_comments ?? true)) {
            return response()->json([
                'message' => __('wishlist.comments_disabled'),
            ], 403);
        }

        $data = $request->validate([
            'text' => ['required', 'string', 'max:2000'],
        ]);

        $comment = WishComment::create([
            'wish_id' => $wish->id,
            'user_id' => $user->id,
            'text' => $data['text'],
        ]);

        $comment->load('user');

        return response()->json([
            'message' => __('wishlist.comment_created'),
            'data' => new WishCommentResource($comment),
        ], 201);
    }

    /**
     * Обновить комментарий.
     */
    public function update(Request $request, Wish $wish, WishComment $comment)
    {
        $user = $request->user();

        // Только автор может редактировать свой комментарий
        if ($comment->user_id !== $user->id) {
            return response()->json([
                'message' => __('wishlist.comment_not_yours'),
            ], 403);
        }

        $data = $request->validate([
            'text' => ['required', 'string', 'max:2000'],
        ]);

        $comment->update(['text' => $data['text']]);
        $comment->load('user');

        return response()->json([
            'message' => __('wishlist.comment_updated'),
            'data' => new WishCommentResource($comment),
        ]);
    }

    /**
     * Удалить комментарий.
     */
    public function destroy(Request $request, Wish $wish, WishComment $comment)
    {
        $user = $request->user();

        // Автор комментария или владелец желания могут удалить комментарий
        if ($comment->user_id !== $user->id && $wish->owner_id !== $user->id) {
            return response()->json([
                'message' => __('wishlist.comment_delete_forbidden'),
            ], 403);
        }

        $comment->delete();

        return response()->json([
            'message' => __('wishlist.comment_deleted'),
        ]);
    }

    /**
     * Проверка доступа к желанию.
     */
    private function authorizeWishAccess(Wish $wish, $user): void
    {
        // Публичные желания доступны всем
        if ($wish->visibility === 'public') {
            return;
        }

        // Желания по ссылке доступны авторизованным пользователям
        if ($wish->visibility === 'link' && $user) {
            return;
        }

        // Личные желания доступны только владельцу и участникам списка
        if ($wish->visibility === 'personal') {
            if (!$user) {
                abort(403, __('wishlist.access_denied'));
            }

            if ($wish->owner_id === $user->id) {
                return;
            }

            // Проверяем участие в списке
            if ($wish->wishlist && $wish->wishlist->participants()->where('user_id', $user->id)->exists()) {
                return;
            }

            abort(403, __('wishlist.access_denied'));
        }
    }
}
