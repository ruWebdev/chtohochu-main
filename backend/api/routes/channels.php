<?php

use App\Models\ShoppingList;
use Illuminate\Support\Facades\Broadcast;

/*
|--------------------------------------------------------------------------
| Broadcast Channels
|--------------------------------------------------------------------------
|
| Каналы авторизации для WebSocket-событий.
| Бизнес-каналы авторизуются по membership соответствующей
| сущности (docs/20-backend/realtime-events.md §5).
|
*/

// Стандартный канал Laravel для модели User.
// User::id — UUID (string); сравнение строгое, приведение к int здесь
// делало бы авторизацию всегда успешной для любого id.
Broadcast::channel('App.Models.User.{id}', function ($user, $id) {
    return $user->id === $id;
}, ['guards' => ['web', 'sanctum']]);

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
}, ['guards' => ['web', 'sanctum']]);

/*
|--------------------------------------------------------------------------
| Shopping List Channels
|--------------------------------------------------------------------------
*/

/**
 * Канал совместного списка покупок `private-shopping-list.{id}`.
 * Только участники списка (владелец или member) — удалённый
 * участник теряет доступ к подписке автоматически.
 */
Broadcast::channel('shopping-list.{listId}', function ($user, $listId) {
    $list = ShoppingList::find($listId);

    return $list !== null && $list->hasMember($user);
}, ['guards' => ['web', 'sanctum']]);
