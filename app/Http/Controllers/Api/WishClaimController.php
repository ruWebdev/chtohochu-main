<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\WishClaimerResource;
use App\Http\Resources\WishResource;
use App\Models\Wish;
use App\Models\WishClaim;
use App\Models\WishHistory;
use Illuminate\Http\Request;

/**
 * Контроллер бронирования желаний (claim).
 */
class WishClaimController extends Controller
{
    /**
     * Получить список тех, кто забронировал желание.
     */
    public function index(Request $request, Wish $wish)
    {
        $user = $request->user();
        $isOwner = $user && $wish->owner_id === $user->id;

        // Если владелец не разрешил показывать claimers, возвращаем пустой список
        // (кроме самого владельца)
        if (!$isOwner && $wish->wishlist && !($wish->wishlist->show_claimers ?? true)) {
            return response()->json([
                'data' => [],
            ]);
        }

        $claimers = $wish->claimers()
            ->with('user')
            ->get();

        return WishClaimerResource::collection($claimers);
    }

    /**
     * Забронировать желание (claim).
     */
    public function store(Request $request, Wish $wish)
    {
        $user = $request->user();

        // Нельзя забронировать своё желание
        if ($wish->owner_id === $user->id) {
            return response()->json([
                'message' => __('wishlist.cannot_claim_own'),
            ], 403);
        }

        // Проверяем, разрешено ли бронирование
        if (!($wish->allow_claiming ?? true)) {
            return response()->json([
                'message' => __('wishlist.claiming_disabled'),
            ], 403);
        }

        // Проверяем, не забронировал ли уже
        $existingClaim = WishClaim::where('wish_id', $wish->id)
            ->where('user_id', $user->id)
            ->first();

        if ($existingClaim) {
            return response()->json([
                'message' => __('wishlist.already_claimed'),
            ], 400);
        }

        $data = $request->validate([
            'is_secret' => ['sometimes', 'boolean'],
        ]);

        $claim = WishClaim::create([
            'wish_id' => $wish->id,
            'user_id' => $user->id,
            'claimed_at' => now(),
            'is_secret' => $data['is_secret'] ?? false,
        ]);

        // Записываем в историю
        WishHistory::create([
            'wish_id' => $wish->id,
            'user_id' => $user->id,
            'action' => WishHistory::ACTION_CLAIMED,
            'changes' => [
                'is_secret' => $data['is_secret'] ?? false,
            ],
        ]);

        $wish->load('claimers.user');

        return response()->json([
            'message' => __('wishlist.claimed'),
            'data' => new WishResource($wish),
        ], 201);
    }

    /**
     * Отменить бронирование (unclaim).
     */
    public function destroy(Request $request, Wish $wish)
    {
        $user = $request->user();

        $claim = WishClaim::where('wish_id', $wish->id)
            ->where('user_id', $user->id)
            ->first();

        if (!$claim) {
            return response()->json([
                'message' => __('wishlist.not_claimed'),
            ], 400);
        }

        $claim->delete();

        // Записываем в историю
        WishHistory::create([
            'wish_id' => $wish->id,
            'user_id' => $user->id,
            'action' => WishHistory::ACTION_UNCLAIMED,
        ]);

        $wish->load('claimers.user');

        return response()->json([
            'message' => __('wishlist.unclaimed'),
            'data' => new WishResource($wish),
        ]);
    }
}
