<?php

namespace App\Http\Controllers\Api;

use App\Events\Wish\WishDeleted;
use App\Events\Wish\WishUpdated;
use App\Events\User\WishlistNewWishAdded;
use App\Events\Wishlist\WishlistItemAdded;
use App\Events\Wishlist\WishlistItemRemoved;
use App\Http\Controllers\Controller;
use App\Http\Requests\Wishlist\StoreWishRequest;
use App\Http\Requests\Wishlist\UpdateWishRequest;
use App\Models\AppNotification;
use App\Models\Wishlist;
use App\Models\Wish;
use App\Models\User;
use App\Services\PushNotificationService;
use Illuminate\Http\Request;
use App\Http\Resources\WishResource;

class WishController extends Controller
{
    /**
     * Список желаний внутри указанного списка желаний.
     */
    public function index(Request $request, Wishlist $wishlist)
    {
        $this->authorize('view', $wishlist);

        $query = $wishlist->wishes()->with([
            'claimers.user',
            'comments.user',
        ]);

        if ($request->filled('status')) {
            $query->whereIn('status', (array) $request->input('status'));
        }

        if ($request->filled('visibility')) {
            $query->whereIn('visibility', (array) $request->input('visibility'));
        }

        if ($request->filled('necessity')) {
            $query->whereIn('necessity', (array) $request->input('necessity'));
        }

        return WishResource::collection($query->get());
    }

    /**
     * Создание желания внутри списка желаний.
     * Доступно владельцу списка и участникам с ролью editor.
     */
    public function store(StoreWishRequest $request, Wishlist $wishlist, PushNotificationService $pushNotificationService)
    {
        $this->authorize('addWish', $wishlist);

        $currentUser = $request->user();

        $data = $request->validated();
        $data['wishlist_id'] = $wishlist->id;
        // Владелец желания — тот, кто его создаёт (не обязательно владелец списка)
        $data['owner_id'] = $currentUser->id;

        if (empty($data['visibility'])) {
            $data['visibility'] = $wishlist->visibility;
        }

        if (empty($data['necessity'])) {
            $data['necessity'] = Wish::NECESSITY_LATER;
        }

        if (empty($data['status'])) {
            $data['status'] = Wish::STATUS_NOT_FULFILLED;
        }

        $wish = Wish::query()->create($data);
        $wish->load(['claimers.user', 'comments.user']);

        // Отправляем WebSocket-событие о добавлении желания в список
        broadcast(new WishlistItemAdded($wishlist, $wish))->toOthers();

        $recipients = $wishlist->participants()
            ->with('notificationSetting')
            ->get();

        if ($recipients->isNotEmpty()) {
            foreach ($recipients as $recipient) {
                AppNotification::create([
                    'user_id' => $recipient->id,
                    'type' => AppNotification::TYPE_WISHLIST_NEW_WISH,
                    'title' => __('notifications.wishlist_new_wish_title'),
                    'body' => __('notifications.wishlist_new_wish_body', [
                        'author' => $currentUser->name,
                        'list' => $wishlist->name,
                        'wish' => $wish->name,
                    ]),
                    'data' => [
                        'list_id' => $wishlist->id,
                        'list_name' => $wishlist->name,
                        'wish_id' => $wish->id,
                        'wish_name' => $wish->name,
                        'author_id' => $currentUser->id,
                        'author_name' => $currentUser->name,
                    ],
                ]);

                broadcast(new WishlistNewWishAdded($recipient, $wishlist, $wish, $currentUser));
            }

            $pushRecipients = $recipients->filter(static function (User $user) {
                $settings = $user->notificationSetting;

                if (! $settings) {
                    return false;
                }

                return $settings->push_enabled && $settings->new_wishes;
            });

            if ($pushRecipients->isNotEmpty()) {
                $pushNotificationService->sendToUsers(
                    users: $pushRecipients,
                    title: __('notifications.wishlist_new_wish_title'),
                    body: __('notifications.wishlist_new_wish_body', [
                        'author' => $currentUser->name,
                        'list' => $wishlist->name,
                        'wish' => $wish->name,
                    ]),
                    data: [
                        'type' => AppNotification::TYPE_WISHLIST_NEW_WISH,
                        'list_id' => $wishlist->id,
                        'wish_id' => $wish->id,
                    ]
                );
            }
        }

        return response()->json([
            'message' => __('wishlist.wish_created'),
            'data' => new WishResource($wish),
        ], 201);
    }

    public function storeStandalone(StoreWishRequest $request)
    {
        $user = $request->user();

        $data = $request->validated();
        $data['wishlist_id'] = null;
        $data['owner_id'] = $user->id;

        if (empty($data['visibility'])) {
            $data['visibility'] = Wish::VISIBILITY_PERSONAL;
        }

        if (empty($data['necessity'])) {
            $data['necessity'] = Wish::NECESSITY_LATER;
        }

        if (empty($data['status'])) {
            $data['status'] = Wish::STATUS_NOT_FULFILLED;
        }

        $wish = Wish::query()->create($data);
        $wish->load(['claimers.user', 'comments.user']);

        return response()->json([
            'message' => __('wishlist.wish_created'),
            'data' => new WishResource($wish),
        ], 201);
    }

    /**
     * Просмотр одного желания в списке.
     */
    public function show(Request $request, Wishlist $wishlist, Wish $wish)
    {
        $this->authorize('view', $wishlist);

        if ($wish->wishlist_id !== $wishlist->id) {
            abort(404);
        }

        $wish->load(['claimers.user', 'comments.user']);

        return new WishResource($wish);
    }

    /**
     * Обновление желания.
     * Доступно владельцу списка и участникам с ролью editor (только свои желания).
     */
    public function update(UpdateWishRequest $request, Wishlist $wishlist, Wish $wish)
    {
        if ($wish->wishlist_id !== $wishlist->id) {
            abort(404);
        }

        // Проверяем право на редактирование с учётом владельца желания
        if (! $request->user()->can('editWish', [$wishlist, $wish->owner_id])) {
            abort(403);
        }

        // Запоминаем изменённые поля для события
        $wish->fill($request->validated());
        $updatedFields = array_keys($wish->getDirty());

        $wish->save();

        $wish->load(['claimers.user', 'comments.user']);

        // Отправляем WebSocket-событие об обновлении желания
        if (! empty($updatedFields)) {
            broadcast(new WishUpdated($wish, $updatedFields))->toOthers();
        }

        return response()->json([
            'message' => __('wishlist.wish_updated'),
            'data' => new WishResource($wish),
        ]);
    }

    /**
     * Удаление желания.
     * Доступно владельцу списка и участникам с ролью editor (только свои желания).
     */
    public function destroy(Request $request, Wishlist $wishlist, Wish $wish)
    {
        if ($wish->wishlist_id !== $wishlist->id) {
            abort(404);
        }

        // Проверяем право на удаление с учётом владельца желания
        if (! $request->user()->can('deleteWish', [$wishlist, $wish->owner_id])) {
            abort(403);
        }

        $wishId = $wish->id;
        $wishlistId = $wishlist->id;

        $wish->delete();

        // Отправляем WebSocket-события об удалении желания
        broadcast(new WishlistItemRemoved($wishlist, $wishId))->toOthers();
        broadcast(new WishDeleted($wishId, $wishlistId));

        return response()->json([
            'message' => __('wishlist.wish_deleted'),
        ]);
    }

    /**
     * Обновление standalone-желания (без списка).
     */
    public function updateStandalone(UpdateWishRequest $request, Wish $wish)
    {
        if ($wish->wishlist_id !== null) {
            abort(404);
        }

        $this->authorize('update', $wish);

        $wish->fill($request->validated());
        $updatedFields = array_keys($wish->getDirty());

        $wish->save();

        $wish->load('claimers.user');

        // Отправляем WebSocket-событие об обновлении желания
        if (! empty($updatedFields)) {
            broadcast(new WishUpdated($wish, $updatedFields))->toOthers();
        }

        return response()->json([
            'message' => __('wishlist.wish_updated'),
            'data' => new WishResource($wish),
        ]);
    }

    /**
     * Удаление standalone-желания (без списка).
     */
    public function destroyStandalone(Request $request, Wish $wish)
    {
        if ($wish->wishlist_id !== null) {
            abort(404);
        }

        $this->authorize('delete', $wish);

        $wishId = $wish->id;

        $wish->delete();

        // Отправляем WebSocket-событие об удалении желания
        broadcast(new WishDeleted($wishId, null));

        return response()->json([
            'message' => __('wishlist.wish_deleted'),
        ]);
    }

    /**
     * Список участников желания.
     */
    public function participants(Request $request, Wishlist $wishlist, Wish $wish)
    {
        $this->authorize('view', $wishlist);

        if ($wish->wishlist_id !== $wishlist->id) {
            abort(404);
        }

        return response()->json([
            'data' => $wish->participants()->get(),
        ]);
    }

    /**
     * Добавление участника к желанию.
     */
    public function addParticipant(Request $request, Wishlist $wishlist, Wish $wish)
    {
        $this->authorize('update', $wishlist);

        if ($wish->wishlist_id !== $wishlist->id) {
            abort(404);
        }

        $data = $request->validate([
            'user_id' => ['required', 'string', 'exists:users,id'],
        ]);

        $wish->participants()->syncWithoutDetaching([$data['user_id']]);

        return response()->json([
            'message' => __('wishlist.wish_participant_added'),
            'data' => $wish->participants()->get(),
        ]);
    }

    /**
     * Удаление участника из желания.
     */
    public function removeParticipant(Request $request, Wishlist $wishlist, Wish $wish, User $user)
    {
        $this->authorize('update', $wishlist);

        if ($wish->wishlist_id !== $wishlist->id) {
            abort(404);
        }

        $wish->participants()->detach($user->id);

        return response()->json([
            'message' => __('wishlist.wish_participant_removed'),
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

        $query = Wish::query()
            ->whereIn('owner_id', $friendIds)
            ->where(function ($q) {
                $q->whereNull('wishlist_id')
                    ->orWhereHas('wishlist', function ($q2) {
                        $q2->whereIn('visibility', [
                            Wishlist::VISIBILITY_LINK,
                            Wishlist::VISIBILITY_PUBLIC,
                        ]);
                    });
            })
            ->whereIn('visibility', [
                Wish::VISIBILITY_LINK,
                Wish::VISIBILITY_PUBLIC,
            ])
            ->with([
                'claimers.user',
                'comments.user',
            ]);

        if ($request->filled('status')) {
            $query->whereIn('status', (array) $request->input('status'));
        }

        if ($request->filled('visibility')) {
            $query->whereIn('visibility', (array) $request->input('visibility'));
        }

        if ($request->filled('necessity')) {
            $query->whereIn('necessity', (array) $request->input('necessity'));
        }

        return WishResource::collection($query->get());
    }

    public function public(Request $request)
    {
        $user = $request->user();

        $query = Wish::query()
            ->where('visibility', Wish::VISIBILITY_PUBLIC)
            ->where('owner_id', '!=', $user->id)
            ->where(function ($q) {
                $q->whereNull('wishlist_id')
                    ->orWhereHas('wishlist', function ($q2) {
                        $q2->where('visibility', Wishlist::VISIBILITY_PUBLIC);
                    });
            })
            ->with([
                'claimers.user',
                'comments.user',
            ]);

        if ($request->filled('status')) {
            $query->whereIn('status', (array) $request->input('status'));
        }

        if ($request->filled('necessity')) {
            $query->whereIn('necessity', (array) $request->input('necessity'));
        }

        return WishResource::collection($query->get());
    }
}
