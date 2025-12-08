<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Friendship;
use App\Models\User;
use App\Models\UserBlock;
use Illuminate\Http\Request;

class UserController extends Controller
{
    /**
     * Поиск пользователей по имени / email / телефону / username.
     */
    public function search(Request $request)
    {
        $currentUser = $request->user();

        $data = $request->validate([
            'query' => ['required_without:email', 'string', 'max:255'],
            'email' => ['sometimes', 'string', 'max:255'],
            'exclude_friends' => ['sometimes', 'boolean'],
        ]);

        $search = $data['query'] ?? $data['email'];
        $excludeFriends = $data['exclude_friends'] ?? true;

        $query = User::query()
            ->where('id', '!=', $currentUser->id)
            ->where(function ($q) use ($search) {
                $like = '%' . $search . '%';

                $q->where('name', 'like', $like)
                    ->orWhere('email', 'like', $like)
                    ->orWhere('phone', 'like', $like)
                    ->orWhere('username', 'like', $like);
            });

        if ($excludeFriends) {
            $friendIds = $currentUser->friendIds();

            if ($friendIds !== []) {
                $query->whereNotIn('id', $friendIds);
            }
        }

        $blockedIds = UserBlock::query()
            ->where('user_id', $currentUser->id)
            ->pluck('blocked_user_id');

        $blockedByIds = UserBlock::query()
            ->where('blocked_user_id', $currentUser->id)
            ->pluck('user_id');

        $blockedAll = $blockedIds->merge($blockedByIds)->unique()->values()->all();

        if ($blockedAll !== []) {
            $query->whereNotIn('id', $blockedAll);
        }

        $users = $query
            ->orderBy('name')
            ->limit(20)
            ->get();

        $ids = $users->pluck('id');

        $friendships = Friendship::query()
            ->where(function ($q) use ($currentUser, $ids) {
                $q->where('requester_id', $currentUser->id)
                    ->whereIn('addressee_id', $ids);
            })
            ->orWhere(function ($q) use ($currentUser, $ids) {
                $q->where('addressee_id', $currentUser->id)
                    ->whereIn('requester_id', $ids);
            })
            ->get();

        $statusByUser = [];

        foreach ($friendships as $friendship) {
            $otherId = $friendship->requester_id === $currentUser->id
                ? $friendship->addressee_id
                : $friendship->requester_id;

            $statusByUser[$otherId] = $friendship->status;
        }

        $result = $users->map(function (User $user) use ($statusByUser) {
            return [
                'id' => $user->id,
                'name' => $user->name,
                'username' => $user->username,
                'avatar' => $user->avatar,
                'friendship_status' => $statusByUser[$user->id] ?? null,
            ];
        })->values();

        return response()->json([
            'data' => $result,
        ]);
    }

    public function block(Request $request, User $user)
    {
        $currentUser = $request->user();

        if ($currentUser->id === $user->id) {
            return response()->json([
                'message' => __('friends.cannot_block_self'),
            ], 422);
        }

        UserBlock::query()->firstOrCreate([
            'user_id' => $currentUser->id,
            'blocked_user_id' => $user->id,
        ]);

        Friendship::query()
            ->where(function ($q) use ($currentUser, $user) {
                $q->where('requester_id', $currentUser->id)
                    ->where('addressee_id', $user->id);
            })
            ->orWhere(function ($q) use ($currentUser, $user) {
                $q->where('requester_id', $user->id)
                    ->where('addressee_id', $currentUser->id);
            })
            ->update(['status' => Friendship::STATUS_BLOCKED]);

        return response()->json([
            'message' => __('friends.user_blocked'),
        ]);
    }

    public function unblock(Request $request, User $user)
    {
        $currentUser = $request->user();

        UserBlock::query()
            ->where('user_id', $currentUser->id)
            ->where('blocked_user_id', $user->id)
            ->delete();

        return response()->json([
            'message' => __('friends.user_unblocked'),
        ]);
    }

    public function blocked(Request $request)
    {
        $currentUser = $request->user();

        $blocks = UserBlock::query()
            ->where('user_id', $currentUser->id)
            ->with('blockedUser')
            ->get();

        $data = $blocks->map(function (UserBlock $block) {
            $user = $block->blockedUser;

            return [
                'id' => $user?->id,
                'name' => $user?->name,
                'username' => $user?->username,
                'avatar' => $user?->avatar,
                'blocked_at' => optional($block->created_at)?->toISOString(),
            ];
        })->filter(fn($item) => $item['id'] !== null)->values();

        return response()->json([
            'data' => $data,
        ]);
    }
}
