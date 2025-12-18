<?php

namespace App\Enums;

/**
 * Единый registry всех доменных событий приложения.
 * Определяет типы событий, каналы доставки (WebSocket/Push) и настройки.
 */
enum NotificationEventType: string
{
    // ========================================================================
    // Списки желаний
    // ========================================================================
    case LIST_CREATED = 'list_created';
    case LIST_SHARED = 'list_shared';
    case LIST_RENAMED = 'list_renamed';
    case LIST_DELETED = 'list_deleted';

        // ========================================================================
        // Участники списка желаний
        // ========================================================================
    case MEMBER_INVITED = 'member_invited';
    case MEMBER_JOINED = 'member_joined';
    case MEMBER_LEFT = 'member_left';
    case MEMBER_REMOVED = 'member_removed';

        // ========================================================================
        // Желания
        // ========================================================================
    case WISH_CREATED = 'wish_created';
    case WISH_UPDATED = 'wish_updated';
    case WISH_PRIORITY_CHANGED = 'wish_priority_changed';
    case WISH_MARKED_DONE = 'wish_marked_done';
    case WISH_COMMENTED = 'wish_commented';

        // ========================================================================
        // Списки покупок
        // ========================================================================
    case SHOPPING_LIST_CREATED = 'shopping_list_created';
    case SHOPPING_LIST_SHARED = 'shopping_list_shared';
    case SHOPPING_LIST_RENAMED = 'shopping_list_renamed';
    case SHOPPING_LIST_DELETED = 'shopping_list_deleted';

        // ========================================================================
        // Участники списка покупок
        // ========================================================================
    case SHOPPING_MEMBER_INVITED = 'shopping_member_invited';
    case SHOPPING_MEMBER_JOINED = 'shopping_member_joined';
    case SHOPPING_MEMBER_LEFT = 'shopping_member_left';
    case SHOPPING_MEMBER_REMOVED = 'shopping_member_removed';

        // ========================================================================
        // Позиции списка покупок
        // ========================================================================
    case ITEM_ADDED = 'item_added';
    case ITEM_UPDATED = 'item_updated';
    case ITEM_CHECKED = 'item_checked';
    case ITEM_UNCHECKED = 'item_unchecked';
    case ITEM_REMOVED = 'item_removed';

        // ========================================================================
        // Шаринг
        // ========================================================================
    case SHARE_LINK_CREATED = 'share_link_created';
    case SHARE_LINK_OPENED = 'share_link_opened';
    case USER_JOINED_VIA_SHARE = 'user_joined_via_share';
    case WISH_ADDED_VIA_SHARE = 'wish_added_via_share';

        // ========================================================================
        // Социальные и сервисные
        // ========================================================================
    case FRIEND_REQUEST = 'friend_request';
    case FRIEND_ACCEPTED = 'friend_accepted';
    case SYSTEM_ANNOUNCEMENT = 'system_announcement';

    /**
     * Требуется ли WebSocket для данного события.
     */
    public function requiresWebSocket(): bool
    {
        return match ($this) {
            self::SYSTEM_ANNOUNCEMENT => false,
            default => true,
        };
    }

    /**
     * Требуется ли Push для данного события.
     */
    public function requiresPush(): bool
    {
        return match ($this) {
            // Списки желаний
            self::LIST_CREATED, self::LIST_RENAMED => false,
            self::LIST_SHARED, self::LIST_DELETED => true,

            // Участники списка желаний
            self::MEMBER_INVITED, self::MEMBER_JOINED,
            self::MEMBER_LEFT, self::MEMBER_REMOVED => true,

            // Желания
            self::WISH_CREATED, self::WISH_UPDATED,
            self::WISH_PRIORITY_CHANGED => false,
            self::WISH_MARKED_DONE, self::WISH_COMMENTED => true,

            // Списки покупок
            self::SHOPPING_LIST_CREATED, self::SHOPPING_LIST_RENAMED => false,
            self::SHOPPING_LIST_SHARED, self::SHOPPING_LIST_DELETED => true,

            // Участники списка покупок
            self::SHOPPING_MEMBER_INVITED, self::SHOPPING_MEMBER_JOINED,
            self::SHOPPING_MEMBER_LEFT, self::SHOPPING_MEMBER_REMOVED => true,

            // Позиции списка покупок
            self::ITEM_ADDED, self::ITEM_UPDATED,
            self::ITEM_UNCHECKED, self::ITEM_REMOVED => false,
            self::ITEM_CHECKED => true,

            // Шаринг
            self::SHARE_LINK_CREATED, self::SHARE_LINK_OPENED => false,
            self::USER_JOINED_VIA_SHARE, self::WISH_ADDED_VIA_SHARE => true,

            // Социальные
            self::FRIEND_REQUEST, self::FRIEND_ACCEPTED => true,
            self::SYSTEM_ANNOUNCEMENT => true,
        };
    }

    /**
     * Получить ключ настройки для проверки согласия пользователя.
     */
    public function getSettingKey(): ?string
    {
        return match ($this) {
            // Участие в списках желаний
            self::LIST_SHARED, self::LIST_DELETED,
            self::MEMBER_INVITED, self::MEMBER_JOINED,
            self::MEMBER_LEFT, self::MEMBER_REMOVED => 'list_invites',

            // Желания
            self::WISH_MARKED_DONE => 'wish_fulfilled',
            self::WISH_COMMENTED => 'wish_comments',

            // Списки покупок — приглашения
            self::SHOPPING_LIST_SHARED, self::SHOPPING_LIST_DELETED,
            self::SHOPPING_MEMBER_INVITED, self::SHOPPING_MEMBER_JOINED,
            self::SHOPPING_MEMBER_LEFT, self::SHOPPING_MEMBER_REMOVED => 'shopping_list_invites',

            // Списки покупок — отметка товара
            self::ITEM_CHECKED => 'shopping_item_checked',

            // Социальные
            self::FRIEND_REQUEST, self::FRIEND_ACCEPTED => 'friend_requests',

            // Шаринг
            self::USER_JOINED_VIA_SHARE, self::WISH_ADDED_VIA_SHARE => 'share_notifications',

            // Системные
            self::SYSTEM_ANNOUNCEMENT => 'system_announcements',

            // События без push — настройка не требуется
            default => null,
        };
    }

    /**
     * Получить человекочитаемое название события.
     */
    public function getLabel(): string
    {
        return match ($this) {
            self::LIST_CREATED => 'Список создан',
            self::LIST_SHARED => 'Список расшарен',
            self::LIST_RENAMED => 'Список переименован',
            self::LIST_DELETED => 'Список удалён',

            self::MEMBER_INVITED => 'Приглашение в список',
            self::MEMBER_JOINED => 'Участник присоединился',
            self::MEMBER_LEFT => 'Участник вышел',
            self::MEMBER_REMOVED => 'Участник удалён',

            self::WISH_CREATED => 'Желание добавлено',
            self::WISH_UPDATED => 'Желание изменено',
            self::WISH_PRIORITY_CHANGED => 'Приоритет изменён',
            self::WISH_MARKED_DONE => 'Желание исполнено',
            self::WISH_COMMENTED => 'Комментарий к желанию',

            self::SHOPPING_LIST_CREATED => 'Список покупок создан',
            self::SHOPPING_LIST_SHARED => 'Список покупок расшарен',
            self::SHOPPING_LIST_RENAMED => 'Список покупок переименован',
            self::SHOPPING_LIST_DELETED => 'Список покупок удалён',

            self::SHOPPING_MEMBER_INVITED => 'Приглашение в список покупок',
            self::SHOPPING_MEMBER_JOINED => 'Участник присоединился',
            self::SHOPPING_MEMBER_LEFT => 'Участник вышел',
            self::SHOPPING_MEMBER_REMOVED => 'Участник удалён',

            self::ITEM_ADDED => 'Товар добавлен',
            self::ITEM_UPDATED => 'Товар изменён',
            self::ITEM_CHECKED => 'Товар куплен',
            self::ITEM_UNCHECKED => 'Отмена покупки',
            self::ITEM_REMOVED => 'Товар удалён',

            self::SHARE_LINK_CREATED => 'Ссылка создана',
            self::SHARE_LINK_OPENED => 'Ссылка открыта',
            self::USER_JOINED_VIA_SHARE => 'Пользователь присоединился по ссылке',
            self::WISH_ADDED_VIA_SHARE => 'Желание скопировано по ссылке',

            self::FRIEND_REQUEST => 'Запрос в друзья',
            self::FRIEND_ACCEPTED => 'Запрос принят',
            self::SYSTEM_ANNOUNCEMENT => 'Системное сообщение',
        };
    }
}
