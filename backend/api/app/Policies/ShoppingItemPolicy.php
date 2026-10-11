<?php

namespace App\Policies;

use App\Models\ShoppingItem;
use App\Models\ShoppingList;
use App\Models\User;

/**
 * Доступ к позиции определяется членством в её списке:
 * item access → membership of parent ShoppingList.
 */
class ShoppingItemPolicy
{
    /**
     * Добавление позиции — владелец и участники списка.
     */
    public function create(User $user, ShoppingList $list): bool
    {
        return $list->hasMember($user);
    }

    /**
     * Просмотр позиции — участникам списка.
     */
    public function view(User $user, ShoppingItem $item): bool
    {
        return $item->list->hasMember($user);
    }

    /**
     * Изменение позиции (включая is_checked) — участникам списка.
     */
    public function update(User $user, ShoppingItem $item): bool
    {
        return $item->list->hasMember($user);
    }

    /**
     * Удаление позиции — участникам списка.
     */
    public function delete(User $user, ShoppingItem $item): bool
    {
        return $item->list->hasMember($user);
    }
}
