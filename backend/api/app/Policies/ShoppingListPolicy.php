<?php

namespace App\Policies;

use App\Models\ShoppingList;
use App\Models\User;

class ShoppingListPolicy
{
    /**
     * Просмотр списка — владелец и участники.
     */
    public function view(User $user, ShoppingList $list): bool
    {
        return $list->hasMember($user);
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

    /**
     * Просмотр участников — владелец и участники.
     */
    public function viewMembers(User $user, ShoppingList $list): bool
    {
        return $list->hasMember($user);
    }

    /**
     * Добавление участника — только владелец (и только друзей,
     * проверка дружбы — в контроллере).
     */
    public function addMember(User $user, ShoppingList $list): bool
    {
        return $user->id === $list->owner_id;
    }

    /**
     * Удаление участника: владелец — любого (кроме себя),
     * участник — только себя (выход из списка).
     */
    public function removeMember(User $user, ShoppingList $list, User $member): bool
    {
        if ($member->id === $list->owner_id) {
            return false;
        }

        return $user->id === $list->owner_id || $user->id === $member->id;
    }
}
