<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class NotificationSetting extends Model
{
    use HasFactory, HasUuids;

    protected $table = 'notification_settings';
    protected $keyType = 'string';
    public $incrementing = false;

    protected $fillable = [
        'user_id',
        'push_enabled',
        'friend_requests',
        'wish_fulfilled',
        'reminders',
        'new_wishes',
        // Новые поля согласно спецификации
        'list_invites',
        'list_member_changes',
        'wish_comments',
        'shopping_list_invites',
        'shopping_member_changes',
        'shopping_item_checked',
        'system_announcements',
    ];

    protected $casts = [
        'push_enabled' => 'bool',
        'friend_requests' => 'bool',
        'wish_fulfilled' => 'bool',
        'reminders' => 'bool',
        'new_wishes' => 'bool',
        'list_invites' => 'bool',
        'list_member_changes' => 'bool',
        'wish_comments' => 'bool',
        'shopping_list_invites' => 'bool',
        'shopping_member_changes' => 'bool',
        'shopping_item_checked' => 'bool',
        'system_announcements' => 'bool',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
