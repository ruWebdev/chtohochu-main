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
        if ($wishlist->owner_id === $user->id) {
            return true;
        }

        if ($wishlist->participants()
            ->where('users.id', $user->id)
            ->exists()
        ) {
            return true;
        }

        if ($wishlist->visibility === Wishlist::VISIBILITY_PUBLIC) {
            return true;
        }

        if ($wishlist->visibility === Wishlist::VISIBILITY_FRIENDS) {
            $friendIds = $user->friendIds();

            return in_array($wishlist->owner_id, $friendIds, true);
        }

        return false;
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
