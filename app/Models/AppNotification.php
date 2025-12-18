<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Модель уведомлений приложения.
 * Хранит уведомления для пользователей (приглашения в списки, запросы в друзья и т.д.)
 */
class AppNotification extends Model
{
    use HasUuids;

    // Типы уведомлений
    public const TYPE_WISHLIST_INVITE = 'wishlist_invite';
    public const TYPE_WISHLIST_NEW_WISH = 'wishlist_new_wish';
    public const TYPE_SHOPPING_LIST_INVITE = 'shopping_list_invite';
    public const TYPE_SHOPPING_LIST_REMOVED = 'shopping_list_removed';
    public const TYPE_SHOPPING_LIST_LEFT = 'shopping_list_left';
    public const TYPE_SHOPPING_LIST_PARTICIPANT_ADDED = 'shopping_list_participant_added';
    public const TYPE_FRIEND_REQUEST = 'friend_request';
    public const TYPE_FRIEND_ACCEPTED = 'friend_accepted';
    public const TYPE_WISH_COMMENT = 'wish_comment';
    public const TYPE_WISH_LIKE = 'wish_like';

    protected $fillable = [
        'user_id',
        'type',
        'title',
        'body',
        'data',
        'is_read',
    ];

    protected $casts = [
        'data' => 'array',
        'is_read' => 'boolean',
    ];

    /**
     * Пользователь, которому принадлежит уведомление.
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Пометить уведомление как прочитанное.
     */
    public function markAsRead(): void
    {
        $this->update(['is_read' => true]);
    }
}
