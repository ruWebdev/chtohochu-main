<?php

namespace App\Http\Controllers\Api;

use App\Events\ShoppingListEvent;
use App\Http\Controllers\Controller;
use App\Http\Requests\Api\StoreShoppingListRequest;
use App\Http\Requests\Api\UpdateShoppingListRequest;
use App\Http\Resources\ShoppingListResource;
use App\Models\ShoppingList;
use Illuminate\Database\QueryException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;

class ShoppingListController extends Controller
{
    /**
     * Списки текущего пользователя: свои + shared (membership)
     * с items и participants (eager loading, без N+1),
     * created_at DESC — как во frontend (новые первые).
     */
    public function index(Request $request): AnonymousResourceCollection
    {
        $user = $request->user();
        $lists = ShoppingList::query()
            ->where('owner_id', $user->id)
            ->orWhereHas('members', fn ($q) => $q->whereKey($user->id))
            ->with(['items', 'owner', 'members'])
            ->latest('created_at')
            ->get();

        return ShoppingListResource::collection($lists);
    }

    /**
     * Создание списка. owner_id — auth()->id(), из request
     * не принимается. 201.
     */
    public function store(StoreShoppingListRequest $request): JsonResponse
    {
        $id = $request->validated('id');
        abort_if(
            $id !== null && ShoppingList::whereKey($id)->exists(),
            409,
            'Resource already exists.'
        );

        try {
            $list = $request->user()->shoppingLists()->create($request->validated());
        } catch (QueryException $e) {
            abort_if($this->isDuplicateKeyViolation($e), 409, 'Resource already exists.');

            throw $e;
        }

        $list->setRelation('items', collect());
        $list->setRelation('members', collect());
        $list->setRelation('owner', $request->user());

        event(ShoppingListEvent::forList(
            $list,
            'shopping_list.created',
            $this->listPayload($list),
            $request->user()->id,
        ));

        return (new ShoppingListResource($list))
            ->toResponse($request)
            ->setStatusCode(201);
    }

    /**
     * Список с items и participants. Владелец/участник
     * (ShoppingListPolicy::view); чужой → 404.
     */
    public function show(Request $request, ShoppingList $shoppingList): ShoppingListResource
    {
        abort_unless($request->user()->can('view', $shoppingList), 404);

        $shoppingList->load(['items', 'owner', 'members']);

        return new ShoppingListResource($shoppingList);
    }

    /**
     * Переименование. Только title — owner/items/created_at
     * отсутствуют в Form Request. Только владелец.
     */
    public function update(UpdateShoppingListRequest $request, ShoppingList $shoppingList): ShoppingListResource
    {
        abort_unless($request->user()->can('update', $shoppingList), 404);

        DB::transaction(function () use ($request, $shoppingList) {
            $shoppingList->update($request->validated());
            $shoppingList->bumpRevision();
        });
        $shoppingList->load(['items', 'owner', 'members']);

        event(ShoppingListEvent::forList(
            $shoppingList,
            'shopping_list.updated',
            $this->listPayload($shoppingList),
            $request->user()->id,
        ));

        return new ShoppingListResource($shoppingList);
    }

    /**
     * Полностью разрешённый snapshot списка для event payload.
     *
     * `JsonResource::resolve()` не раскрывает вложенные ресурсы
     * (owner/members/items остаются объектами) — BroadcastEvent
     * сериализовал бы живые модели. Проход через toResponse
     * даёт ровно API-форму, включая `data`-обёртку.
     *
     * @return array<string, mixed>
     */
    private function listPayload(ShoppingList $list): array
    {
        $response = (new ShoppingListResource($list))
            ->toResponse(request());
        $decoded = json_decode($response->getContent(), true);

        return is_array($decoded) ? ($decoded['data'] ?? $decoded) : [];
    }

    /**
     * Удаление списка. Только владелец. Items и membership
     * удаляются каскадом FK на уровне БД. 204.
     */
    public function destroy(Request $request, ShoppingList $shoppingList): JsonResponse
    {
        abort_unless($request->user()->can('delete', $shoppingList), 404);

        // Получатели события — снимок до удаления: participants
        // исчезают вместе со списком каскадом FK.
        $participantIds = $shoppingList->participantIds();
        DB::transaction(function () use ($shoppingList) {
            $shoppingList->bumpRevision();
            $shoppingList->delete();
        });

        event(ShoppingListEvent::forList(
            $shoppingList,
            'shopping_list.deleted',
            ['deleted' => true],
            $request->user()->id,
            $participantIds,
        ));

        return response()->json(null, 204);
    }
}
