<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\FriendRequestResource;
use App\Http\Resources\FriendResource;
use App\Models\Friendship;
use App\Models\User;
use App\Models\UserBlock;
use Illuminate\Http\Request;

class FriendController extends Controller
{
    /**
     * Список друзей текущего пользователя.
     * Поддерживает поиск и пагинацию.
     */
    public function index(Request $request)
    {
        $user = $request->user();

        $friendIds = $user->friendIds();

        $perPage = (int) $request->input('per_page', 20);
        $perPage = $perPage > 0 && $perPage <= 100 ? $perPage : 20;

        if ($friendIds === []) {
            return response()->json([
                'data' => [],
                'meta' => [
                    'total' => 0,
                    'page' => 1,
                    'per_page' => $perPage,
                ],
            ]);
        }

        $query = User::query()
            ->whereIn('id', $friendIds);

        if ($request->filled('search')) {
            $search = (string) $request->input('search');

            $query->where(function ($q) use ($search) {
                $like = '%' . $search . '%';

                $q->where('name', 'like', $like)
                    ->orWhere('email', 'like', $like)
                    ->orWhere('username', 'like', $like)
                    ->orWhere('phone', 'like', $like);
            });
        }

        $filter = (string) $request->input('filter', 'all');

        if ($filter === 'recent') {
            $query->orderByDesc('created_at');
        } else {
            $query->orderBy('name');
        }

        $paginator = $query->paginate($perPage);

        $collection = $paginator->getCollection()->map(function (User $friend) use ($request) {
            $friend->setAttribute('friendship_status', 'accepted');
            $friend->setAttribute('mutual_lists_count', 0);

            return (new FriendResource($friend))->toArray($request);
        })->values();

        return response()->json([
            'data' => $collection,
            'meta' => [
                'total' => $paginator->total(),
                'page' => $paginator->currentPage(),
                'per_page' => $paginator->perPage(),
            ],
        ]);
    }

    /**
     * Отправка заявки в друзья.
     */
    public function sendRequest(Request $request)
    {
        $user = $request->user();

        $data = $request->validate([
            'user_id' => ['required', 'string', 'exists:users,id'],
            'message' => ['nullable', 'string', 'max:500'],
        ]);

        if ($data['user_id'] === $user->id) {
            return response()->json([
                'message' => __('friends.cannot_add_self'),
            ], 422);
        }

        $isBlocked = UserBlock::query()
            ->where(function ($q) use ($user, $data) {
                $q->where('user_id', $user->id)
                    ->where('blocked_user_id', $data['user_id']);
            })
            ->orWhere(function ($q) use ($user, $data) {
                $q->where('user_id', $data['user_id'])
                    ->where('blocked_user_id', $user->id);
            })
            ->exists();

        if ($isBlocked) {
            return response()->json([
                'message' => __('friends.cannot_add_blocked'),
            ], 422);
        }

        $existing = Friendship::query()
            ->where(function ($q) use ($user, $data) {
                $q->where('requester_id', $user->id)
                    ->where('addressee_id', $data['user_id']);
            })
            ->orWhere(function ($q) use ($user, $data) {
                $q->where('requester_id', $data['user_id'])
                    ->where('addressee_id', $user->id);
            })
            ->first();

        if ($existing !== null) {
            if ($existing->status === Friendship::STATUS_ACCEPTED) {
                return response()->json([
                    'message' => __('friends.already_friends'),
                ], 422);
            }

            return response()->json([
                'message' => __('friends.request_already_exists'),
            ], 422);
        }

        $friendship = Friendship::query()->create([
            'requester_id' => $user->id,
            'addressee_id' => $data['user_id'],
            'status' => Friendship::STATUS_PENDING,
            'message' => $data['message'] ?? null,
        ]);

        return response()->json([
            'message' => __('friends.request_sent'),
            'data' => new FriendRequestResource($friendship->load(['requester', 'addressee'])),
        ], 201);
    }

    /**
     * Подтверждение заявки в друзья.
     */
    public function accept(Request $request, Friendship $friendship)
    {
        $user = $request->user();

        if ($friendship->addressee_id !== $user->id) {
            abort(403);
        }

        if ($friendship->status !== Friendship::STATUS_PENDING) {
            return response()->json([
                'message' => __('friends.cannot_accept'),
            ], 422);
        }

        $friendship->status = Friendship::STATUS_ACCEPTED;
        $friendship->save();

        return response()->json([
            'message' => __('friends.request_accepted'),
            'data' => [
                'id' => $friendship->id,
                'status' => $friendship->status,
                'updated_at' => optional($friendship->updated_at)?->toISOString(),
            ],
        ]);
    }

    /**
     * Отклонение заявки в друзья.
     */
    public function reject(Request $request, Friendship $friendship)
    {
        $user = $request->user();

        if ($friendship->addressee_id !== $user->id) {
            abort(403);
        }

        $friendship->status = Friendship::STATUS_DECLINED;
        $friendship->save();

        return response()->json([
            'message' => __('friends.request_rejected'),
            'data' => [
                'id' => $friendship->id,
                'status' => $friendship->status,
                'updated_at' => optional($friendship->updated_at)?->toISOString(),
            ],
        ]);
    }

    /**
     * Входящие заявки в друзья для текущего пользователя.
     */
    public function incoming(Request $request)
    {
        $user = $request->user();

        $requests = Friendship::query()
            ->where('addressee_id', $user->id)
            ->where('status', Friendship::STATUS_PENDING)
            ->with(['requester', 'addressee'])
            ->get();

        return response()->json([
            'data' => FriendRequestResource::collection($requests),
        ]);
    }

    /**
     * Обратная совместимость для старого эндпоинта /friends/requests/pending.
     */
    public function pending(Request $request)
    {
        return $this->incoming($request);
    }

    /**
     * Исходящие заявки в друзья текущего пользователя.
     */
    public function outgoing(Request $request)
    {
        $user = $request->user();

        $requests = Friendship::query()
            ->where('requester_id', $user->id)
            ->where('status', Friendship::STATUS_PENDING)
            ->with(['requester', 'addressee'])
            ->get();

        return response()->json([
            'data' => FriendRequestResource::collection($requests),
        ]);
    }

    /**
     * Отмена исходящего запроса в друзья.
     */
    public function cancel(Request $request, Friendship $friendship)
    {
        $user = $request->user();

        if ($friendship->requester_id !== $user->id) {
            abort(403);
        }

        if ($friendship->status !== Friendship::STATUS_PENDING) {
            return response()->json([
                'message' => __('friends.cannot_cancel'),
            ], 422);
        }

        $friendship->delete();

        return response()->noContent();
    }

    /**
     * Удаление друга.
     */
    public function destroy(Request $request, User $friend)
    {
        $user = $request->user();

        Friendship::query()
            ->where(function ($q) use ($user, $friend) {
                $q->where('requester_id', $user->id)
                    ->where('addressee_id', $friend->id);
            })
            ->orWhere(function ($q) use ($user, $friend) {
                $q->where('requester_id', $friend->id)
                    ->where('addressee_id', $user->id);
            })
            ->delete();

        return response()->noContent();
    }
}
