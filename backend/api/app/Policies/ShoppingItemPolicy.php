<?php

namespace App\Policies;

use App\Models\ShoppingItem;
use App\Models\ShoppingList;
use App\Models\User;

/**
 * Доступ к позиции определяется владением её списком:
 * item access → ownership of parent ShoppingList.
 */
class ShoppingItemPolicy
{
    /**
     * Добавление позиции в список — только владельцу списка.
     */
    public function create(User $user, ShoppingList $list): bool
    {
        return $user->id === $list->owner_id;
    }

    /**
     * Просмотр позиции — владельцу списка.
     */
    public function view(User $user, ShoppingItem $item): bool
    {
        return $user->id === $item->list->owner_id;
    }

    /**
     * Изменение позиции — владельцу списка.
     */
    public function update(User $user, ShoppingItem $item): bool
    {
        return $user->id === $item->list->owner_id;
    }

    /**
     * Удаление позиции — владельцу списка.
     */
    public function delete(User $user, ShoppingItem $item): bool
    {
        return $user->id === $item->list->owner_id;
    }
}
