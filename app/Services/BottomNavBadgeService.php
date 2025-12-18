<?php

namespace App\Services;

use App\Models\BottomNavBadge;
use App\Models\User;
use App\Events\System\BottomNavBadgeUpdated;

/**
 * Сервис для управления индикаторами bottom navigation bar.
 * Централизует логику установки и сброса индикаторов.
 */
class BottomNavBadgeService
{
    /**
     * Получить состояние индикаторов для пользователя.
     */
    public function getBadges(string $userId): array
    {
        $badge = BottomNavBadge::getOrCreateForUser($userId);
        return $badge->toStateArray();
    }

    /**
     * Установить индикатор для указанного экрана.
     * Отправляет событие через WebSocket для real-time обновления.
     */
    public function setBadge(string $userId, string $screen): bool
    {
        if (!in_array($screen, BottomNavBadge::VALID_SCREENS, true)) {
            return false;
        }

        $badge = BottomNavBadge::getOrCreateForUser($userId);

        // Если индикатор уже установлен, не отправляем событие повторно
        if ($badge->{$screen}) {
            return true;
        }

        $badge->setBadge($screen, true);

        // Отправляем событие через WebSocket
        event(new BottomNavBadgeUpdated($userId, $badge->toStateArray()));

        return true;
    }

    /**
     * Сбросить индикатор для указанного экрана (при открытии экрана).
     */
    public function clearBadge(string $userId, string $screen): bool
    {
        if (!in_array($screen, BottomNavBadge::VALID_SCREENS, true)) {
            return false;
        }

        $badge = BottomNavBadge::getOrCreateForUser($userId);

        // Если индикатор уже сброшен, ничего не делаем
        if (!$badge->{$screen}) {
            return true;
        }

        $badge->clearBadge($screen);

        // Отправляем событие через WebSocket
        event(new BottomNavBadgeUpdated($userId, $badge->toStateArray()));

        return true;
    }

    /**
     * Установить индикатор wishlist для списка пользователей.
     * Используется при событиях в списках желаний.
     * 
     * @param array $userIds Массив ID пользователей
     * @param string|null $excludeUserId ID пользователя, которого исключить (инициатор действия)
     */
    public function setWishlistBadgeForUsers(array $userIds, ?string $excludeUserId = null): void
    {
        foreach ($userIds as $userId) {
            if ($excludeUserId && $userId === $excludeUserId) {
                continue;
            }
            $this->setBadge($userId, BottomNavBadge::SCREEN_WISHLIST);
        }
    }

    /**
     * Установить индикатор purchases для списка пользователей.
     * Используется при событиях в списках покупок.
     * 
     * @param array $userIds Массив ID пользователей
     * @param string|null $excludeUserId ID пользователя, которого исключить (инициатор действия)
     */
    public function setPurchasesBadgeForUsers(array $userIds, ?string $excludeUserId = null): void
    {
        foreach ($userIds as $userId) {
            if ($excludeUserId && $userId === $excludeUserId) {
                continue;
            }
            $this->setBadge($userId, BottomNavBadge::SCREEN_PURCHASES);
        }
    }

    /**
     * Установить индикатор friends для пользователя.
     * Используется при событиях дружбы.
     */
    public function setFriendsBadge(string $userId): void
    {
        $this->setBadge($userId, BottomNavBadge::SCREEN_FRIENDS);
    }
}
