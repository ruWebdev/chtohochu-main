<?php

namespace App\Policies;

use App\Models\Wishlist;
use App\Models\User;

class WishlistPolicy
{
    /**
     * Просмотр списка желаний.
     */
    public function view(User $user, Wishlist $wishlist): bool
    {
        return $wishlist->owner_id === $user->id;
    }

    /**
     * Обновление списка желаний.
     */
    public function update(User $user, Wishlist $wishlist): bool
    {
        return $wishlist->owner_id === $user->id;
    }

    /**
     * Удаление списка желаний.
     */
    public function delete(User $user, Wishlist $wishlist): bool
    {
        return $wishlist->owner_id === $user->id;
    }
}
