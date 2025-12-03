<?php

namespace App\Policies;

use App\Models\ShoppingList;
use App\Models\User;

class ShoppingListPolicy
{
    /**
     * Просмотр списка покупок.
     */
    public function view(User $user, ShoppingList $shoppingList): bool
    {
        if ($shoppingList->owner_id === $user->id) {
            return true;
        }

        return $shoppingList->participants()
            ->where('users.id', $user->id)
            ->exists();
    }

    /**
     * Обновление списка покупок (включая управление пунктами).
     */
    public function update(User $user, ShoppingList $shoppingList): bool
    {
        if ($shoppingList->owner_id === $user->id) {
            return true;
        }

        return $shoppingList->participants()
            ->where('users.id', $user->id)
            ->exists();
    }

    /**
     * Удаление списка покупок.
     */
    public function delete(User $user, ShoppingList $shoppingList): bool
    {
        return $shoppingList->owner_id === $user->id;
    }
}
