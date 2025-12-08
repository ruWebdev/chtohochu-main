<?php

namespace App\Policies;

use App\Models\User;
use App\Models\Wish;

class WishPolicy
{
    public function view(User $user, Wish $wish): bool
    {
        return $wish->owner_id === $user->id;
    }

    public function update(User $user, Wish $wish): bool
    {
        return $wish->owner_id === $user->id;
    }

    public function delete(User $user, Wish $wish): bool
    {
        return $wish->owner_id === $user->id;
    }
}
