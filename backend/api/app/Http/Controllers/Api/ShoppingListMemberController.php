<?php

namespace App\Http\Controllers\Api;

use App\Events\ShoppingListEvent;
use App\Http\Controllers\Controller;
use App\Http\Requests\Api\StoreShoppingListMemberRequest;
use App\Http\Resources\PublicUserResource;
use App\Models\ShoppingList;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;

/**
 * Участники совместного списка покупок.
 *
 * Владелец управляет составом (только друзей); участник может
 * удалить себя (выход из списка). Владелец — участник неявно
 * через owner_id, удалить его нельзя.
 */
class ShoppingListMemberController extends Controller
{
    /**
     * Участники списка: владелец первым, затем members.
     * Только для участников (viewMembers); чужой → 404.
     */
    public function index(Request $request, ShoppingList $shoppingList): AnonymousResourceCollection
    {
        abort_unless($request->user()->can('viewMembers', $shoppingList), 404);

        return PublicUserResource::collection($shoppingList->participants());
    }

    /**
     * Добавление участника. Только владелец, только друга.
     * Повторное добавление идемпотентно — 200 с участником.
     */
    public function store(StoreShoppingListMemberRequest $request, ShoppingList $shoppingList): JsonResponse
    {
        abort_unless($request->user()->can('addMember', $shoppingList), 404);

        $member = User::findOrFail($request->validated('user_id'));

        // Владелец уже участник неявно — добавлять себя бессмысленно.
        abort_if($member->id === $shoppingList->owner_id, 422, 'Owner is already a member.');

        // Только друзья — список не становится доступным
        // произвольному user_id (IDOR-защита уровня домена).
        abort_unless($request->user()->isFriendWith($member), 422, 'User is not a friend.');

        $alreadyMember = $shoppingList->members()->whereKey($member->id)->exists();
        if (! $alreadyMember) {
            DB::transaction(function () use ($shoppingList, $member) {
                $shoppingList->members()->attach($member->id);
                $shoppingList->bumpRevision();
            });

            event(ShoppingListEvent::forList(
                $shoppingList,
                'shopping_list.participant.joined',
                ['user' => (new PublicUserResource($member))->resolve(), 'role' => 'member'],
                $request->user()->id,
            ));
        }

        return (new PublicUserResource($member))
            ->toResponse($request)
            ->setStatusCode($alreadyMember ? 200 : 201);
    }

    /**
     * Удаление участника: владелец — любого member, member —
     * только себя (leave). Владельца удалить нельзя.
     */
    public function destroy(Request $request, ShoppingList $shoppingList, User $user): JsonResponse
    {
        abort_unless($request->user()->can('removeMember', [$shoppingList, $user]), 404);

        $isMember = $shoppingList->members()->whereKey($user->id)->exists();
        if (! $isMember) {
            return response()->json(null, 204);
        }

        DB::transaction(function () use ($shoppingList, $user) {
            $shoppingList->members()->detach($user->id);
            $shoppingList->bumpRevision();
        });

        // Удалённый участник уже не в participantIds() —
        // добавляем его явно, чтобы его клиент узнал о потере
        // доступа и вычистил список при reconcile.
        event(ShoppingListEvent::forList(
            $shoppingList,
            'shopping_list.participant.left',
            ['user_id' => $user->id],
            $request->user()->id,
            [...$shoppingList->participantIds(), $user->id],
        ));

        return response()->json(null, 204);
    }
}
