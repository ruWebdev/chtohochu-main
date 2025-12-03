<?php

namespace App\Services;

use App\Models\User;
use App\Models\Wish;

class UserStatisticsService
{
    public function getStatisticsForUser(User $user): array
    {
        $totalWishes = Wish::query()
            ->whereHas('wishlist', function ($query) use ($user) {
                $query->where('owner_id', $user->id);
            })
            ->count();

        $fulfilledWishes = Wish::query()
            ->whereHas('wishlist', function ($query) use ($user) {
                $query->where('owner_id', $user->id);
            })
            ->where('status', Wish::STATUS_FULFILLED)
            ->count();

        $friendsCount = $user->friends()->count();

        return [
            'wishes_total' => $totalWishes,
            'wishes_fulfilled' => $fulfilledWishes,
            'friends_total' => $friendsCount,
        ];
    }
}
