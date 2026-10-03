<?php

namespace App\Policies;

use App\Models\User;

class UserPolicy
{
    /**
     * Просмотр профиля пользователя как друга.
     * MVP: профиль через friends-endpoint видят только друзья.
     */
    public function view(User $user, User $target): bool
    {
        return $user->isFriendWith($target);
    }

    /**
     * Просмотр желаний пользователя: владелец или accepted-друг.
     */
    public function viewWishes(User $user, User $target): bool
    {
        return $user->id === $target->id || $user->isFriendWith($target);
    }
}
