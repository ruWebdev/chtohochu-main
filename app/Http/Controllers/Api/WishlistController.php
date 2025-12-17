<?php

namespace App\Http\Controllers\Api;

use App\Events\User\UserTaggedInList;
use App\Events\Wishlist\WishlistDeleted;
use App\Events\Wishlist\WishlistParticipantAdded;
use App\Events\Wishlist\WishlistParticipantRemoved;
use App\Events\Wishlist\WishlistUpdated;
use App\Http\Controllers\Controller;
use App\Http\Requests\Wishlist\StoreWishlistRequest;
use App\Http\Requests\Wishlist\UpdateWishlistRequest;
use App\Models\Wishlist;
use App\Models\User;
use Illuminate\Http\Request;
use App\Http\Resources\WishlistResource;
use App\Http\Resources\WishlistUserResource;
use App\Models\AppNotification;

class WishlistController extends Controller
{
    /**
     * Список всех списков желаний текущего пользователя.
     */
    public function index(Request $request)
    {
        $user = $request->user();

        $query = Wishlist::query()
            ->where(function ($q) use ($user) {
                $q->where('owner_id', $user->id)
                    ->orWhereHas('participants', function ($q2) use ($user) {
                        $q2->where('users.id', $user->id);
                    });
            })
            ->with([
                'owner',
                'participants',
                'wishes',
                'favorites' => function ($query) use ($user) {
                    $query->where('user_id', $user->id);
                },
            ]);

        if ($request->filled('status')) {
            $query->whereIn('status', (array) $request->input('status'));
        }

        if ($request->filled('visibility')) {
            $query->whereIn('visibility', (array) $request->input('visibility'));
        }

        if ($request->filled('is_favorite')) {
            $rawIsFavorite = $request->input('is_favorite');
            $isFavorite = filter_var($rawIsFavorite, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);

            if ($isFavorite === true) {
                $query->whereHas('favorites', function ($q) use ($user) {
                    $q->where('user_id', $user->id);
                });
            } elseif ($isFavorite === false) {
                $query->whereDoesntHave('favorites', function ($q) use ($user) {
                    $q->where('user_id', $user->id);
                });
            }
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
        $isFavorite = array_key_exists('is_favorite', $data) ? (bool) $data['is_favorite'] : false;
        unset($data['is_favorite']);
        $data['owner_id'] = $user->id;

        if (empty($data['status'])) {
            $data['status'] = Wishlist::STATUS_NEW;
        }

        if (empty($data['visibility'])) {
            $data['visibility'] = Wishlist::VISIBILITY_PERSONAL;
        }

        $wishlist = Wishlist::query()->create($data);

        if ($isFavorite) {
            $wishlist->favorites()->syncWithoutDetaching([$user->id]);
        }

        $wishlist->load([
            'owner',
            'participants',
            'wishes',
            'favorites' => function ($query) use ($user) {
                $query->where('user_id', $user->id);
            },
        ]);

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

        $user = $request->user();

        $wishlist->load([
            'owner',
            'participants',
            'wishes',
            'favorites' => function ($query) use ($user) {
                $query->where('user_id', $user->id);
            },
        ]);

        return new WishlistResource($wishlist);
    }

    /**
     * Обновление списка желаний.
     */
    public function update(UpdateWishlistRequest $request, Wishlist $wishlist)
    {
        $data = $request->validated();
        $user = $request->user();

        $isFavorite = array_key_exists('is_favorite', $data) ? (bool) $data['is_favorite'] : null;
        unset($data['is_favorite']);

        if ($data === []) {
            $this->authorize('view', $wishlist);
            $updatedFields = [];
        } else {
            $this->authorize('update', $wishlist);

            $wishlist->fill($data);

            // Запоминаем изменённые поля для события
            $updatedFields = array_keys($wishlist->getDirty());

            $wishlist->save();
        }

        if ($isFavorite === true) {
            $wishlist->favorites()->syncWithoutDetaching([$user->id]);
        } elseif ($isFavorite === false) {
            $wishlist->favorites()->detach($user->id);
        }

        $wishlist->load([
            'owner',
            'participants',
            'wishes',
            'favorites' => function ($query) use ($user) {
                $query->where('user_id', $user->id);
            },
        ]);

        // Отправляем WebSocket-событие об обновлении списка
        if (! empty($updatedFields)) {
            broadcast(new WishlistUpdated($wishlist, $updatedFields))->toOthers();
        }

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

        // Собираем данные для события до удаления
        $wishlistId = $wishlist->id;
        $wishlistName = $wishlist->name;
        $participantIds = $wishlist->participants()->pluck('users.id')->toArray();

        $wishlist->delete();

        // Отправляем WebSocket-событие об удалении списка
        broadcast(new WishlistDeleted($wishlistId, $wishlistName, $participantIds));

        return response()->json([
            'message' => __('wishlist.wishlist_deleted'),
        ]);
    }

    /**
     * Список участников списка желаний.
     * Доступно только владельцу и участникам списка.
     */
    public function participants(Request $request, Wishlist $wishlist)
    {
        $this->authorize('viewParticipants', $wishlist);

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

        // Получаем добавленного участника
        $participant = User::find($data['user_id']);

        if ($participant) {
            // Отправляем событие в канал списка
            broadcast(new WishlistParticipantAdded($wishlist, $participant))->toOthers();

            // Уведомляем добавленного пользователя
            broadcast(new UserTaggedInList($participant, $wishlist, $currentUser));

            // Сохраняем уведомление в БД
            AppNotification::create([
                'user_id' => $participant->id,
                'type' => AppNotification::TYPE_WISHLIST_INVITE,
                'title' => __('notifications.wishlist_invite_title'),
                'body' => __('notifications.wishlist_invite_body', [
                    'inviter' => $currentUser->name,
                    'list' => $wishlist->name,
                ]),
                'data' => [
                    'list_id' => $wishlist->id,
                    'list_name' => $wishlist->name,
                    'inviter_id' => $currentUser->id,
                    'inviter_name' => $currentUser->name,
                ],
            ]);
        }

        return response()->json([
            'message' => __('wishlist.participant_added'),
            'data' => new WishlistResource($wishlist),
        ]);
    }

    /**
     * Обновление роли участника списка желаний.
     */
    public function updateParticipant(Request $request, Wishlist $wishlist, User $user)
    {
        $currentUser = $request->user();

        if ($currentUser->id !== $wishlist->owner_id) {
            abort(403);
        }

        if ($user->id === $wishlist->owner_id) {
            return response()->json([
                'message' => __('wishlist.cannot_change_owner_role'),
            ], 422);
        }

        $data = $request->validate([
            'role' => ['required', 'string', 'in:viewer,editor'],
        ]);

        $wishlist->participants()->updateExistingPivot($user->id, [
            'role' => $data['role'],
        ]);

        $participant = $wishlist->participants()
            ->where('users.id', $user->id)
            ->first();

        if (! $participant) {
            abort(404);
        }

        return response()->json([
            'message' => __('wishlist.participant_role_updated'),
            'data' => new WishlistUserResource($participant),
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

        // Проверяем, что пользователь является участником
        if (! $wishlist->participants()->where('users.id', $user->id)->exists()) {
            return response()->json([
                'message' => __('wishlist.user_not_participant'),
            ], 404);
        }

        $userId = $user->id;

        $wishlist->participants()->detach($user->id);

        // Отправляем WebSocket-событие об удалении участника
        broadcast(new WishlistParticipantRemoved($wishlist, $userId))->toOthers();

        return response()->json([
            'message' => __('wishlist.participant_removed'),
        ]);
    }

    /**
     * Покинуть список желаний (для участников).
     */
    public function leave(Request $request, Wishlist $wishlist)
    {
        $this->authorize('leave', $wishlist);

        $user = $request->user();

        $wishlist->participants()->detach($user->id);

        // Отправляем WebSocket-событие об удалении участника
        broadcast(new WishlistParticipantRemoved($wishlist, $user->id))->toOthers();

        return response()->json([
            'message' => __('wishlist.left_list'),
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
                Wishlist::VISIBILITY_LINK,
                Wishlist::VISIBILITY_PUBLIC,
            ])
            ->with([
                'owner',
                'participants',
                'wishes',
                'favorites' => function ($query) use ($user) {
                    $query->where('user_id', $user->id);
                },
            ]);

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
            ->with([
                'owner',
                'participants',
                'wishes',
                'favorites' => function ($query) use ($user) {
                    $query->where('user_id', $user->id);
                },
            ]);

        if ($request->filled('status')) {
            $query->whereIn('status', (array) $request->input('status'));
        }

        return WishlistResource::collection($query->get());
    }
}
