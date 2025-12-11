<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Shopping\StoreShoppingListRequest;
use App\Http\Requests\Shopping\UpdateShoppingListRequest;
use App\Models\ShoppingList;
use App\Models\ShoppingListActivity;
use App\Models\User;
use App\Models\AppNotification;
use App\Events\User\UserTaggedInShoppingList;
use Illuminate\Http\Request;
use App\Http\Resources\ShoppingListResource;

class ShoppingListController extends Controller
{
    /**
     * Список всех доступных пользователю списков покупок.
     */
    public function index(Request $request)
    {
        $user = $request->user();

        $query = ShoppingList::query()
            ->where(function ($q) use ($user) {
                $q->where('owner_id', $user->id)
                    ->orWhereHas('participants', function ($q2) use ($user) {
                        $q2->where('users.id', $user->id);
                    });
            })
            ->with(['items', 'owner', 'participants']);

        if ($request->filled('status')) {
            $query->whereIn('status', (array) $request->input('status'));
        }

        if ($request->filled('visibility')) {
            $query->whereIn('visibility', (array) $request->input('visibility'));
        }

        if ($request->filled('q')) {
            $search = $request->input('q');
            $query->where('name', 'like', '%' . $search . '%');
        }

        $query->orderBy('created_at', 'desc');

        return ShoppingListResource::collection($query->get());
    }

    /**
     * Создание нового списка покупок.
     */
    public function store(StoreShoppingListRequest $request)
    {
        $user = $request->user();

        $data = $request->validated();
        $data['owner_id'] = $user->id;

        if (empty($data['status'])) {
            $data['status'] = ShoppingList::STATUS_NEW;
        }

        $shoppingList = ShoppingList::query()->create($data);

        $shoppingList->load(['items', 'owner', 'participants']);

        return response()->json([
            'message' => __('shopping.list_created'),
            'data' => new ShoppingListResource($shoppingList),
        ], 201);
    }

    /**
     * Просмотр конкретного списка покупок.
     */
    public function show(Request $request, ShoppingList $shoppingList)
    {
        $this->authorize('view', $shoppingList);

        $shoppingList->load(['items', 'owner', 'participants']);

        return new ShoppingListResource($shoppingList);
    }

    /**
     * Обновление списка покупок.
     */
    public function update(UpdateShoppingListRequest $request, ShoppingList $shoppingList)
    {
        $this->authorize('update', $shoppingList);

        $data = $request->validated();

        $shoppingList->fill($data);
        $shoppingList->save();

        $shoppingList->load(['items', 'owner', 'participants']);

        return response()->json([
            'message' => __('shopping.list_updated'),
            'data' => new ShoppingListResource($shoppingList),
        ]);
    }

    /**
     * Удаление списка покупок.
     */
    public function destroy(Request $request, ShoppingList $shoppingList)
    {
        $this->authorize('delete', $shoppingList);

        $shoppingList->delete();

        return response()->json([
            'message' => __('shopping.list_deleted'),
        ]);
    }

    /**
     * Список участников совместного списка покупок.
     */
    public function participants(Request $request, ShoppingList $shoppingList)
    {
        $this->authorize('view', $shoppingList);

        return response()->json([
            'data' => $shoppingList->participants()->get(),
        ]);
    }

    /**
     * Добавление участника в совместный список покупок.
     */
    public function addParticipant(Request $request, ShoppingList $shoppingList)
    {
        $currentUser = $request->user();

        if ($currentUser->id !== $shoppingList->owner_id) {
            abort(403);
        }

        $data = $request->validate([
            'user_id' => ['required', 'string', 'exists:users,id'],
        ]);

        if ($data['user_id'] === $shoppingList->owner_id) {
            return response()->json([
                'message' => __('shopping.cannot_add_owner_as_participant'),
            ], 422);
        }

        $shoppingList->participants()->syncWithoutDetaching([$data['user_id']]);

        $shoppingList->load(['items', 'owner', 'participants']);

        // Получаем добавленного участника
        $participant = User::find($data['user_id']);

        if ($participant) {
            // Уведомляем добавленного пользователя через WebSocket
            broadcast(new UserTaggedInShoppingList($participant, $shoppingList, $currentUser));

            // Сохраняем уведомление в БД
            AppNotification::create([
                'user_id' => $participant->id,
                'type' => AppNotification::TYPE_SHOPPING_LIST_INVITE,
                'title' => __('notifications.shopping_list_invite_title'),
                'body' => __('notifications.shopping_list_invite_body', [
                    'inviter' => $currentUser->name,
                    'list' => $shoppingList->name,
                ]),
                'data' => [
                    'list_id' => $shoppingList->id,
                    'list_name' => $shoppingList->name,
                    'inviter_id' => $currentUser->id,
                    'inviter_name' => $currentUser->name,
                ],
            ]);
        }

        return response()->json([
            'message' => __('shopping.participant_added'),
            'data' => new ShoppingListResource($shoppingList),
        ]);
    }

    /**
     * Удаление участника из совместного списка покупок.
     */
    public function removeParticipant(Request $request, ShoppingList $shoppingList, User $user)
    {
        $currentUser = $request->user();

        if ($currentUser->id !== $shoppingList->owner_id) {
            abort(403);
        }

        if ($user->id === $shoppingList->owner_id) {
            return response()->json([
                'message' => __('shopping.cannot_remove_owner'),
            ], 422);
        }

        $shoppingList->participants()->detach($user->id);

        return response()->json([
            'message' => __('shopping.participant_removed'),
        ]);
    }

    public function reorder(Request $request)
    {
        $user = $request->user();

        $data = $request->validate([
            'order' => ['required', 'array'],
            'order.*' => ['string', 'distinct'],
        ]);

        $ids = $data['order'];

        if ($ids === []) {
            return response()->json([
                'data' => [],
            ]);
        }

        $lists = ShoppingList::query()
            ->whereIn('id', $ids)
            ->where(function ($q) use ($user) {
                $q->where('owner_id', $user->id)
                    ->orWhereHas('participants', function ($q2) use ($user) {
                        $q2->where('users.id', $user->id);
                    });
            })
            ->get()
            ->keyBy('id');

        $position = 0;

        foreach ($ids as $id) {
            if (! isset($lists[$id])) {
                continue;
            }

            $list = $lists[$id];
            $list->sort_order = $position;
            $list->save();

            $position++;
        }

        return response()->json([
            'message' => __('shopping.list_updated'),
            'data' => $lists->values(),
        ]);
    }

    public function activity(Request $request, ShoppingList $shoppingList)
    {
        $this->authorize('view', $shoppingList);

        $data = $request->validate([
            'since' => ['sometimes', 'date'],
        ]);

        $query = $shoppingList->activities()
            ->with('user')
            ->orderBy('created_at', 'desc');

        if (! empty($data['since'])) {
            $query->where('created_at', '>=', $data['since']);
        }

        return response()->json([
            'data' => $query->get(),
        ]);
    }

    public function activeUsers(Request $request)
    {
        $data = $request->validate([
            'since' => ['sometimes', 'date'],
        ]);

        $since = $data['since'] ?? now()->subMinutes(15);

        $activities = ShoppingListActivity::query()
            ->with(['shoppingList', 'user'])
            ->where('created_at', '>=', $since)
            ->get()
            ->groupBy('shopping_list_id');

        $result = [];

        foreach ($activities as $shoppingListId => $listActivities) {
            $users = $listActivities->pluck('user')->filter()->unique('id')->values();

            $result[] = [
                'shopping_list_id' => $shoppingListId,
                'users' => $users,
            ];
        }

        return response()->json([
            'data' => $result,
        ]);
    }
}
