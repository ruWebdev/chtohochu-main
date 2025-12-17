<?php

namespace App\Policies;

use App\Models\Wishlist;
use App\Models\User;

class WishlistPolicy
{
    /**
     * Просмотр списка желаний.
     * Доступно: владельцу, участникам, для публичных списков, для списков с visibility=link (без проверки дружбы).
     */
    public function view(User $user, Wishlist $wishlist): bool
    {
        // Владелец всегда имеет доступ
        if ($wishlist->owner_id === $user->id) {
            return true;
        }

        // Участники имеют доступ
        if ($wishlist->participants()
            ->where('users.id', $user->id)
            ->exists()
        ) {
            return true;
        }

        // Публичные списки доступны всем авторизованным
        if ($wishlist->visibility === Wishlist::VISIBILITY_PUBLIC) {
            return true;
        }

        // Списки с доступом по ссылке доступны всем авторизованным (без проверки дружбы)
        if ($wishlist->visibility === Wishlist::VISIBILITY_LINK) {
            return true;
        }

        return false;
    }

    /**
     * Обновление метаданных списка желаний (название, описание, настройки).
     * Доступно только владельцу.
     */
    public function update(User $user, Wishlist $wishlist): bool
    {
        return $wishlist->owner_id === $user->id;
    }

    /**
     * Удаление списка желаний.
     * Доступно только владельцу.
     */
    public function delete(User $user, Wishlist $wishlist): bool
    {
        return $wishlist->owner_id === $user->id;
    }

    /**
     * Добавление желания в список.
     * Доступно владельцу и участникам с ролью editor.
     */
    public function addWish(User $user, Wishlist $wishlist): bool
    {
        // Владелец может добавлять желания
        if ($wishlist->owner_id === $user->id) {
            return true;
        }

        // Участники с ролью editor могут добавлять желания
        return $wishlist->participants()
            ->where('users.id', $user->id)
            ->where('wishlist_user.role', 'editor')
            ->exists();
    }

    /**
     * Редактирование желания в списке.
     * Доступно владельцу списка и участникам с ролью editor (только свои желания).
     */
    public function editWish(User $user, Wishlist $wishlist, ?string $wishOwnerId = null): bool
    {
        // Владелец списка может редактировать любые желания
        if ($wishlist->owner_id === $user->id) {
            return true;
        }

        // Участники с ролью editor могут редактировать только свои желания
        if ($wishOwnerId !== null && $wishOwnerId === $user->id) {
            return $wishlist->participants()
                ->where('users.id', $user->id)
                ->where('wishlist_user.role', 'editor')
                ->exists();
        }

        return false;
    }

    /**
     * Удаление желания из списка.
     * Доступно владельцу списка и участникам с ролью editor (только свои желания).
     */
    public function deleteWish(User $user, Wishlist $wishlist, ?string $wishOwnerId = null): bool
    {
        // Владелец списка может удалять любые желания
        if ($wishlist->owner_id === $user->id) {
            return true;
        }

        // Участники с ролью editor могут удалять только свои желания
        if ($wishOwnerId !== null && $wishOwnerId === $user->id) {
            return $wishlist->participants()
                ->where('users.id', $user->id)
                ->where('wishlist_user.role', 'editor')
                ->exists();
        }

        return false;
    }

    /**
     * Просмотр списка участников (только список, без возможности управления).
     * Доступно владельцу и всем участникам списка.
     * Используется для отображения аватаров участников в UI.
     */
    public function viewParticipants(User $user, Wishlist $wishlist): bool
    {
        // Владелец может видеть участников
        if ($wishlist->owner_id === $user->id) {
            return true;
        }

        // Участники могут видеть других участников
        return $wishlist->participants()
            ->where('users.id', $user->id)
            ->exists();
    }

    /**
     * Управление участниками (добавление, удаление, изменение ролей).
     * Доступно ТОЛЬКО владельцу.
     * Это единственный метод, который должен использоваться для доступа к странице управления участниками.
     */
    public function manageParticipants(User $user, Wishlist $wishlist): bool
    {
        return $wishlist->owner_id === $user->id;
    }

    /**
     * Покинуть список (для участников).
     * Доступно только участникам (не владельцу).
     */
    public function leave(User $user, Wishlist $wishlist): bool
    {
        // Владелец не может покинуть свой список
        if ($wishlist->owner_id === $user->id) {
            return false;
        }

        // Только участники могут покинуть список
        return $wishlist->participants()
            ->where('users.id', $user->id)
            ->exists();
    }
}
