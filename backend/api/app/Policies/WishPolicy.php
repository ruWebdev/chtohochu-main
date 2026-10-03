<?php

namespace App\Policies;

use App\Models\User;
use App\Models\Wish;

class WishPolicy
{
    /**
     * Может ли пользователь смотреть желание.
     * Владелец или accepted-друг владельца.
     */
    public function view(User $user, Wish $wish): bool
    {
        return $user->id === $wish->owner_id || $user->isFriendWith($wish->owner);
    }

    /**
     * Может ли пользователь изменять желание.
     */
    public function update(User $user, Wish $wish): bool
    {
        return $user->id === $wish->owner_id;
    }

    /**
     * Может ли пользователь удалять желание.
     */
    public function delete(User $user, Wish $wish): bool
    {
        return $user->id === $wish->owner_id;
    }
}
