<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Friendship;
use Illuminate\Http\Request;

class FriendController extends Controller
{
    /**
     * Список друзей текущего пользователя.
     */
    public function index(Request $request)
    {
        $user = $request->user();

        return response()->json([
            'data' => $user->friends(),
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
        ]);

        if ($data['user_id'] === $user->id) {
            return response()->json([
                'message' => __('friends.cannot_add_self'),
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
        ]);

        return response()->json([
            'message' => __('friends.request_sent'),
            'data' => $friendship->load(['requester', 'addressee']),
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
            'data' => $friendship->requester,
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

        $friendship->delete();

        return response()->json([
            'message' => __('friends.request_rejected'),
        ]);
    }

    /**
     * Входящие заявки в друзья для текущего пользователя.
     */
    public function pending(Request $request)
    {
        $user = $request->user();

        $requests = Friendship::query()
            ->where('addressee_id', $user->id)
            ->where('status', Friendship::STATUS_PENDING)
            ->with('requester')
            ->get();

        return response()->json([
            'data' => $requests,
        ]);
    }
}
