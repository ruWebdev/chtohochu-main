<?php

namespace App\Policies;

use App\Models\ShoppingList;
use App\Models\User;

class ShoppingListPolicy
{
    /**
     * Просмотр списка — только владелец.
     */
    public function view(User $user, ShoppingList $list): bool
    {
        return $user->id === $list->owner_id;
    }

    /**
     * Создание списка — любой аутентифицированный пользователь
     * от своего имени (owner_id всегда auth()->id()).
     */
    public function create(User $user): bool
    {
        return true;
    }

    /**
     * Переименование — только владелец.
     */
    public function update(User $user, ShoppingList $list): bool
    {
        return $user->id === $list->owner_id;
    }

    /**
     * Удаление — только владелец.
     */
    public function delete(User $user, ShoppingList $list): bool
    {
        return $user->id === $list->owner_id;
    }
}
