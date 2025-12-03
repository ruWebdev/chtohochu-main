<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Wishlist\StoreWishlistRequest;
use App\Http\Requests\Wishlist\UpdateWishlistRequest;
use App\Models\Wishlist;
use App\Models\User;
use Illuminate\Http\Request;
use App\Http\Resources\WishlistResource;
use App\Http\Resources\WishlistUserResource;

class WishlistController extends Controller
{
    /**
     * Список всех списков желаний текущего пользователя.
     */
    public function index(Request $request)
    {
        $user = $request->user();

        $query = Wishlist::query()
            ->where('owner_id', $user->id)
            ->with(['owner', 'participants', 'wishes']);

        if ($request->filled('status')) {
            $query->whereIn('status', (array) $request->input('status'));
        }

        if ($request->filled('visibility')) {
            $query->whereIn('visibility', (array) $request->input('visibility'));
        }

        return WishlistResource::collection($query->get());
    }

    /**
     * Создание списка желаний.
     */
    public function store(StoreWishlistRequest $request)
    {
        $user = $request->user();

        $data = $request->validated();
        $data['owner_id'] = $user->id;

        if (empty($data['status'])) {
            $data['status'] = Wishlist::STATUS_NEW;
        }

        if (empty($data['visibility'])) {
            $data['visibility'] = Wishlist::VISIBILITY_PERSONAL;
        }

        $wishlist = Wishlist::query()->create($data);

        $wishlist->load(['owner', 'participants', 'wishes']);

        return response()->json([
            'message' => __('wishlist.wishlist_created'),
            'data' => new WishlistResource($wishlist),
        ], 201);
    }

    /**
     * Просмотр конкретного списка желаний.
     */
    public function show(Request $request, Wishlist $wishlist)
    {
        $this->authorize('view', $wishlist);

        $wishlist->load(['owner', 'participants', 'wishes']);

        return new WishlistResource($wishlist);
    }

    /**
     * Обновление списка желаний.
     */
    public function update(UpdateWishlistRequest $request, Wishlist $wishlist)
    {
        $this->authorize('update', $wishlist);

        $wishlist->fill($request->validated());
        $wishlist->save();

        $wishlist->load(['owner', 'participants', 'wishes']);

        return response()->json([
            'message' => __('wishlist.wishlist_updated'),
            'data' => new WishlistResource($wishlist),
        ]);
    }

    /**
     * Удаление списка желаний.
     */
    public function destroy(Request $request, Wishlist $wishlist)
    {
        $this->authorize('delete', $wishlist);

        $wishlist->delete();

        return response()->json([
            'message' => __('wishlist.wishlist_deleted'),
        ]);
    }

    /**
     * Список участников списка желаний.
     */
    public function participants(Request $request, Wishlist $wishlist)
    {
        $this->authorize('view', $wishlist);

        return WishlistUserResource::collection($wishlist->participants()->get());
    }

    /**
     * Добавление участника в список желаний.
     */
    public function addParticipant(Request $request, Wishlist $wishlist)
    {
        $currentUser = $request->user();

        if ($currentUser->id !== $wishlist->owner_id) {
            abort(403);
        }

        $data = $request->validate([
            'user_id' => ['required', 'string', 'exists:users,id'],
        ]);

        if ($data['user_id'] === $wishlist->owner_id) {
            return response()->json([
                'message' => __('wishlist.cannot_add_owner_as_participant'),
            ], 422);
        }

        $wishlist->participants()->syncWithoutDetaching([$data['user_id']]);

        $wishlist->load(['owner', 'participants', 'wishes']);

        return response()->json([
            'message' => __('wishlist.participant_added'),
            'data' => new WishlistResource($wishlist),
        ]);
    }

    /**
     * Удаление участника из списка желаний.
     */
    public function removeParticipant(Request $request, Wishlist $wishlist, User $user)
    {
        $currentUser = $request->user();

        if ($currentUser->id !== $wishlist->owner_id) {
            abort(403);
        }

        if ($user->id === $wishlist->owner_id) {
            return response()->json([
                'message' => __('wishlist.cannot_remove_owner'),
            ], 422);
        }

        $wishlist->participants()->detach($user->id);

        return response()->json([
            'message' => __('wishlist.participant_removed'),
        ]);
    }

    public function friends(Request $request)
    {
        $user = $request->user();

        $friends = $user->friends();
        $friendIds = $friends->pluck('id');

        if ($friendIds->isEmpty()) {
            return response()->json([
                'data' => [],
            ]);
        }

        $query = Wishlist::query()
            ->whereIn('owner_id', $friendIds)
            ->whereIn('visibility', [
                Wishlist::VISIBILITY_FRIENDS,
                Wishlist::VISIBILITY_PUBLIC,
            ])
            ->with(['owner', 'participants', 'wishes']);

        if ($request->filled('status')) {
            $query->whereIn('status', (array) $request->input('status'));
        }

        if ($request->filled('visibility')) {
            $query->whereIn('visibility', (array) $request->input('visibility'));
        }

        return WishlistResource::collection($query->get());
    }

    public function public(Request $request)
    {
        $user = $request->user();

        $query = Wishlist::query()
            ->where('visibility', Wishlist::VISIBILITY_PUBLIC)
            ->where('owner_id', '!=', $user->id)
            ->with(['owner', 'participants', 'wishes']);

        if ($request->filled('status')) {
            $query->whereIn('status', (array) $request->input('status'));
        }

        return WishlistResource::collection($query->get());
    }
}
