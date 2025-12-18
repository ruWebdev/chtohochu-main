<?php

namespace App\Listeners;

use App\Events\ShoppingList\ShoppingListItemCreated;
use App\Events\ShoppingList\ShoppingListItemUpdated;
use App\Events\User\FriendRequestAccepted;
use App\Events\User\FriendRequestSent;
use App\Events\User\UserTaggedInList;
use App\Events\User\UserTaggedInShoppingList;
use App\Events\Wish\WishUpdated;
use App\Events\Wishlist\WishlistItemAdded;
use App\Events\Wishlist\WishlistParticipantAdded;
use App\Models\Friendship;
use App\Models\ShoppingList;
use App\Models\Wishlist;
use App\Services\BottomNavBadgeService;
use Illuminate\Contracts\Queue\ShouldQueue;

/**
 * Слушатель событий для установки индикаторов bottom navigation bar.
 * Обрабатывает все события, которые должны зажигать красную точку.
 */
class BottomNavBadgeListener implements ShouldQueue
{
    public function __construct(
        private BottomNavBadgeService $badgeService
    ) {}

    /**
     * Обработка добавления желания в список.
     * Триггер: wishlist
     */
    public function handleWishlistItemAdded(WishlistItemAdded $event): void
    {
        $wishlist = $event->wishlist;
        $wish = $event->wish;

        // Получаем ID создателя желания
        $creatorId = $wish->user_id;

        // Получаем всех участников списка (владелец + участники)
        $userIds = $this->getWishlistParticipantIds($wishlist);

        // Устанавливаем индикатор всем, кроме создателя желания
        $this->badgeService->setWishlistBadgeForUsers($userIds, $creatorId);
    }

    /**
     * Обработка обновления желания.
     * Триггер: wishlist (при изменении названия, описания, фото, статуса)
     */
    public function handleWishUpdated(WishUpdated $event): void
    {
        $wish = $event->wish;
        $updatedFields = $event->updatedFields;

        // Проверяем, что изменены релевантные поля
        $relevantFields = ['name', 'description', 'images', 'status'];
        $hasRelevantChanges = !empty(array_intersect($relevantFields, $updatedFields));

        if (!$hasRelevantChanges) {
            return;
        }

        // Получаем ID пользователя, который сделал изменение
        $editorId = auth()->id();

        // Если желание привязано к списку
        if ($wish->wishlist_id) {
            $wishlist = $wish->wishlist;
            if ($wishlist) {
                $userIds = $this->getWishlistParticipantIds($wishlist);
                $this->badgeService->setWishlistBadgeForUsers($userIds, $editorId);
            }
        }
    }

    /**
     * Обработка добавления участника в список желаний.
     * Триггер: wishlist (для добавленного пользователя)
     */
    public function handleWishlistParticipantAdded(WishlistParticipantAdded $event): void
    {
        // Устанавливаем индикатор добавленному участнику
        $this->badgeService->setBadge($event->participant->id, 'wishlist');
    }

    /**
     * Обработка тегирования пользователя в списке желаний.
     * Триггер: wishlist + friends (если приглашающий — друг)
     */
    public function handleUserTaggedInList(UserTaggedInList $event): void
    {
        $userId = $event->user->id;
        $inviterId = $event->inviter->id;

        // Устанавливаем индикатор wishlist добавленному пользователю
        $this->badgeService->setBadge($userId, 'wishlist');

        // Если приглашающий — друг, также зажигаем индикатор friends
        // (друг поделился списком желаний)
        if ($this->areFriends($userId, $inviterId)) {
            $this->badgeService->setFriendsBadge($userId);
        }
    }

    /**
     * Обработка создания элемента списка покупок.
     * Триггер: purchases
     */
    public function handleShoppingListItemCreated(ShoppingListItemCreated $event): void
    {
        $item = $event->item;
        $shoppingList = $item->shoppingList;

        if (!$shoppingList) {
            return;
        }

        // Получаем ID создателя элемента
        $creatorId = $item->added_by ?? auth()->id();

        // Получаем всех участников списка покупок
        $userIds = $this->getShoppingListParticipantIds($shoppingList);

        // Устанавливаем индикатор всем, кроме создателя
        $this->badgeService->setPurchasesBadgeForUsers($userIds, $creatorId);
    }

    /**
     * Обработка обновления элемента списка покупок.
     * Триггер: purchases (при изменении количества, комментария, статуса покупки)
     */
    public function handleShoppingListItemUpdated(ShoppingListItemUpdated $event): void
    {
        $item = $event->item;
        $shoppingList = $item->shoppingList;

        if (!$shoppingList) {
            return;
        }

        // Получаем ID пользователя, который сделал изменение
        $editorId = auth()->id();

        // Получаем всех участников списка покупок
        $userIds = $this->getShoppingListParticipantIds($shoppingList);

        // Устанавливаем индикатор всем, кроме редактора
        $this->badgeService->setPurchasesBadgeForUsers($userIds, $editorId);
    }

    /**
     * Обработка тегирования пользователя в списке покупок.
     * Триггер: purchases + friends (если приглашающий — друг)
     */
    public function handleUserTaggedInShoppingList(UserTaggedInShoppingList $event): void
    {
        $userId = $event->user->id;
        $inviterId = $event->inviter->id;

        // Устанавливаем индикатор purchases добавленному пользователю
        $this->badgeService->setBadge($userId, 'purchases');

        // Если приглашающий — друг, также зажигаем индикатор friends
        // (друг открыл доступ к списку покупок)
        if ($this->areFriends($userId, $inviterId)) {
            $this->badgeService->setFriendsBadge($userId);
        }
    }

    /**
     * Обработка входящего запроса в друзья.
     * Триггер: friends (для получателя запроса)
     */
    public function handleFriendRequestSent(FriendRequestSent $event): void
    {
        // Устанавливаем индикатор получателю запроса
        $this->badgeService->setFriendsBadge($event->addressee->id);
    }

    /**
     * Обработка принятия запроса в друзья.
     * Триггер: friends (для отправителя запроса)
     */
    public function handleFriendRequestAccepted(FriendRequestAccepted $event): void
    {
        // Устанавливаем индикатор отправителю запроса (его запрос приняли)
        $this->badgeService->setFriendsBadge($event->requester->id);
    }

    /**
     * Получить ID всех участников списка желаний (владелец + участники).
     */
    private function getWishlistParticipantIds(Wishlist $wishlist): array
    {
        $userIds = [];

        // Владелец списка
        if ($wishlist->owner_id) {
            $userIds[] = $wishlist->owner_id;
        }

        // Участники списка
        $participantIds = $wishlist->participants()->pluck('users.id')->toArray();
        $userIds = array_merge($userIds, $participantIds);

        return array_unique($userIds);
    }

    /**
     * Получить ID всех участников списка покупок (владелец + участники).
     */
    private function getShoppingListParticipantIds(ShoppingList $shoppingList): array
    {
        $userIds = [];

        // Владелец списка
        if ($shoppingList->owner_id) {
            $userIds[] = $shoppingList->owner_id;
        }

        // Участники списка
        $participantIds = $shoppingList->participants()->pluck('users.id')->toArray();
        $userIds = array_merge($userIds, $participantIds);

        return array_unique($userIds);
    }

    /**
     * Проверить, являются ли два пользователя друзьями.
     */
    private function areFriends(string $userId1, string $userId2): bool
    {
        return Friendship::query()
            ->where('status', Friendship::STATUS_ACCEPTED)
            ->where(function ($query) use ($userId1, $userId2) {
                $query->where(function ($q) use ($userId1, $userId2) {
                    $q->where('requester_id', $userId1)
                        ->where('addressee_id', $userId2);
                })->orWhere(function ($q) use ($userId1, $userId2) {
                    $q->where('requester_id', $userId2)
                        ->where('addressee_id', $userId1);
                });
            })
            ->exists();
    }
}
