<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\FriendResource;
use App\Models\Friendship;
use App\Models\Invite;
use App\Models\UserBlock;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class InviteController extends Controller
{
    public function store(Request $request)
    {
        $user = $request->user();

        $code = $this->generateCode();

        $invite = Invite::query()->create([
            'user_id' => $user->id,
            'code' => $code,
            'expires_at' => now()->addDays(7),
        ]);

        return response()->json([
            'data' => [
                'id' => $invite->id,
                'code' => $invite->code,
                'url' => config('app.url') . '/invite/' . $invite->code,
                'expires_at' => optional($invite->expires_at)?->toISOString(),
            ],
        ], 201);
    }

    public function accept(Request $request, string $code)
    {
        $user = $request->user();

        $invite = Invite::query()
            ->where('code', $code)
            ->firstOrFail();

        if ($invite->used_at !== null || ($invite->expires_at !== null && $invite->expires_at->isPast())) {
            return response()->json([
                'message' => __('friends.invite_invalid'),
            ], 422);
        }

        if ($invite->user_id === $user->id) {
            return response()->json([
                'message' => __('friends.cannot_add_self'),
            ], 422);
        }

        $isBlocked = UserBlock::query()
            ->where(function ($q) use ($user, $invite) {
                $q->where('user_id', $user->id)
                    ->where('blocked_user_id', $invite->user_id);
            })
            ->orWhere(function ($q) use ($user, $invite) {
                $q->where('user_id', $invite->user_id)
                    ->where('blocked_user_id', $user->id);
            })
            ->exists();

        if ($isBlocked) {
            return response()->json([
                'message' => __('friends.cannot_add_blocked'),
            ], 422);
        }

        $existing = Friendship::query()
            ->where(function ($q) use ($user, $invite) {
                $q->where('requester_id', $user->id)
                    ->where('addressee_id', $invite->user_id);
            })
            ->orWhere(function ($q) use ($user, $invite) {
                $q->where('requester_id', $invite->user_id)
                    ->where('addressee_id', $user->id);
            })
            ->first();

        if ($existing === null) {
            $existing = Friendship::query()->create([
                'requester_id' => $invite->user_id,
                'addressee_id' => $user->id,
                'status' => Friendship::STATUS_ACCEPTED,
            ]);
        } elseif ($existing->status !== Friendship::STATUS_ACCEPTED) {
            $existing->status = Friendship::STATUS_ACCEPTED;
            $existing->save();
        }

        $invite->used_at = now();
        $invite->used_by = $user->id;
        $invite->save();

        $friend = $invite->user;

        return response()->json([
            'data' => [
                'friend' => (new FriendResource($friend))->toArray($request),
            ],
            'message' => __('friends.invite_accepted'),
        ]);
    }

    protected function generateCode(): string
    {
        return Str::upper(Str::random(6));
    }
}
