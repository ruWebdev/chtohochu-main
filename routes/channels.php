<?php

use App\Models\Wish;
use App\Models\Wishlist;
use Illuminate\Support\Facades\Broadcast;

/*
|--------------------------------------------------------------------------
| Broadcast Channels
|--------------------------------------------------------------------------
|
| Каналы авторизации для WebSocket-событий.
| Документация: docs/WEBSOCKET_EVENTS.md
|
*/

// Стандартный канал Laravel для модели User
Broadcast::channel('App.Models.User.{id}', function ($user, $id) {
    return (int) $user->id === (int) $id;
});

/*
|--------------------------------------------------------------------------
| User Channels
|--------------------------------------------------------------------------
*/

/**
 * Персональные уведомления пользователя.
 * Разрешено только самому пользователю.
 */
Broadcast::channel('user.{userId}', function ($user, $userId) {
    return $user->id === $userId;
});

/**
 * Системные пуши и фоновые операции.
 */
Broadcast::channel('user.actions.{userId}', function ($user, $userId) {
    return $user->id === $userId;
});

/**
 * Presence-канал для онлайн-статуса.
 * Возвращает данные пользователя для отображения в списке онлайн.
 */
Broadcast::channel('user.online.{userId}', function ($user, $userId) {
    if ($user->id === $userId) {
        return [
            'id' => $user->id,
            'name' => $user->name,
            'avatar' => $user->avatar,
        ];
    }

    return false;
});

/*
|--------------------------------------------------------------------------
| List Channels (Wishlists)
|--------------------------------------------------------------------------
*/

/**
 * Presence-канал списка желаний.
 * Разрешено владельцу и участникам.
 */
Broadcast::channel('list.members.{listId}', function ($user, $listId) {
    $wishlist = Wishlist::find($listId);

    if (! $wishlist) {
        return false;
    }

    $hasAccess = $wishlist->owner_id === $user->id
        || $wishlist->participants()->where('user_id', $user->id)->exists();

    if ($hasAccess) {
        return [
            'id' => $user->id,
            'name' => $user->name,
            'avatar' => $user->avatar,
        ];
    }

    return false;
});

/**
 * Приватный канал списка желаний.
 * Разрешено владельцу и участникам (editor/admin).
 */
Broadcast::channel('list.{listId}', function ($user, $listId) {
    $wishlist = Wishlist::find($listId);

    if (! $wishlist) {
        return false;
    }

    return $wishlist->owner_id === $user->id
        || $wishlist->participants()->where('user_id', $user->id)->exists();
});

/**
 * Публичный канал списка желаний.
 * Доступен всем авторизованным пользователям, если список публичный.
 */
Broadcast::channel('list.open.{listId}', function ($user, $listId) {
    $wishlist = Wishlist::find($listId);

    if (! $wishlist) {
        return false;
    }

    return $wishlist->visibility === Wishlist::VISIBILITY_PUBLIC;
});

/*
|--------------------------------------------------------------------------
| Item Channels (Wishes)
|--------------------------------------------------------------------------
*/

/**
 * Приватный канал желания.
 * Разрешено, если у пользователя есть доступ к списку, где находится желание.
 */
Broadcast::channel('item.{itemId}', function ($user, $itemId) {
    $wish = Wish::find($itemId);

    if (! $wish) {
        return false;
    }

    // Standalone-желание (без списка) — доступ только владельцу
    if ($wish->wishlist_id === null) {
        return $wish->owner_id === $user->id;
    }

    $wishlist = $wish->wishlist;

    if (! $wishlist) {
        return false;
    }

    return $wishlist->owner_id === $user->id
        || $wishlist->participants()->where('user_id', $user->id)->exists();
});

/**
 * Presence-канал желания для совместного редактирования.
 */
Broadcast::channel('item.editors.{itemId}', function ($user, $itemId) {
    $wish = Wish::find($itemId);

    if (! $wish) {
        return false;
    }

    // Standalone-желание
    if ($wish->wishlist_id === null) {
        if ($wish->owner_id === $user->id) {
            return [
                'id' => $user->id,
                'name' => $user->name,
                'avatar' => $user->avatar,
            ];
        }

        return false;
    }

    $wishlist = $wish->wishlist;

    if (! $wishlist) {
        return false;
    }

    $hasAccess = $wishlist->owner_id === $user->id
        || $wishlist->participants()->where('user_id', $user->id)->exists();

    if ($hasAccess) {
        return [
            'id' => $user->id,
            'name' => $user->name,
            'avatar' => $user->avatar,
        ];
    }

    return false;
});

/*
|--------------------------------------------------------------------------
| System Channels
|--------------------------------------------------------------------------
*/

/**
 * Публичный канал ленты (тренды, рекомендации).
 * Доступен всем авторизованным пользователям.
 */
Broadcast::channel('feed.global', function ($user) {
    return $user !== null;
});

/**
 * Глобальный системный канал.
 * Доступен всем авторизованным пользователям.
 */
Broadcast::channel('system-global', function ($user) {
    return $user !== null;
});

/**
 * Канал мониторинга для администраторов.
 */
Broadcast::channel('admin-monitor', function ($user) {
    return $user->hasRole('admin');
});
