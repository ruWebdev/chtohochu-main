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
    ];

    protected $casts = [
        'push_enabled' => 'bool',
        'friend_requests' => 'bool',
        'wish_fulfilled' => 'bool',
        'reminders' => 'bool',
        'new_wishes' => 'bool',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
