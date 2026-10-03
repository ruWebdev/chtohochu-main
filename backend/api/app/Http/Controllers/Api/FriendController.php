<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\StoreFriendRequest;
use App\Http\Resources\PublicUserResource;
use App\Http\Resources\WishResource;
use App\Models\Friendship;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class FriendController extends Controller
{
    /**
     * Друзья текущего пользователя (accepted), name ASC.
     */
    public function index(Request $request): AnonymousResourceCollection
    {
        $friends = $request->user()
            ->friends()
            ->orderBy('name')
            ->orderBy('username')
            ->orderBy('users.id')
            ->get();

        return PublicUserResource::collection($friends);
    }

    /**
     * Добавить друга. Дружба симметрична — одна запись.
     * Дубликат (в любом направлении) — 409.
     */
    public function store(StoreFriendRequest $request): JsonResponse
    {
        $friend = User::findOrFail($request->validated('user_id'));
        $user = $request->user();

        if (Friendship::between($user->id, $friend->id)) {
            return response()->json(['message' => 'Friendship already exists.'], 409);
        }

        Friendship::createBetween($user, $friend);

        return (new PublicUserResource($friend))
            ->toResponse($request)
            ->setStatusCode(201);
    }

    /**
     * Публичный профиль друга. Только для accepted-друзей
     * (UserPolicy::view); иначе 404 — существование не раскрываем.
     */
    public function show(Request $request, User $user): PublicUserResource
    {
        abort_unless($request->user()->can('view', $user), 404);

        return new PublicUserResource($user);
    }

    /**
     * Желания друга, created_at DESC.
     * Владелец или accepted-друг (UserPolicy::viewWishes).
     */
    public function wishes(Request $request, User $user): AnonymousResourceCollection
    {
        abort_unless($request->user()->can('viewWishes', $user), 404);

        $wishes = $user->wishes()->latest('created_at')->get();

        return WishResource::collection($wishes);
    }

    /**
     * Удалить дружбу между текущим пользователем и указанным.
     * Нет дружбы → 404. 204 No Content.
     */
    public function destroy(Request $request, User $user): JsonResponse
    {
        $friendship = Friendship::between($request->user()->id, $user->id);

        abort_unless($friendship !== null, 404);

        $friendship->delete();

        return response()->json(null, 204);
    }
}
