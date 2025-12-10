<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * Модель записи истории изменений желания.
 */
class WishHistory extends Model
{
    use HasFactory, HasUuids;

    protected $table = 'wish_history';
    protected $keyType = 'string';
    public $incrementing = false;

    // Только created_at, без updated_at
    const UPDATED_AT = null;

    public const ACTION_CREATED = 'created';
    public const ACTION_UPDATED = 'updated';
    public const ACTION_STATUS_CHANGED = 'status_changed';
    public const ACTION_CLAIMED = 'claimed';
    public const ACTION_UNCLAIMED = 'unclaimed';

    public const ACTIONS = [
        self::ACTION_CREATED,
        self::ACTION_UPDATED,
        self::ACTION_STATUS_CHANGED,
        self::ACTION_CLAIMED,
        self::ACTION_UNCLAIMED,
    ];

    protected $fillable = [
        'wish_id',
        'user_id',
        'action',
        'changes',
    ];

    protected $casts = [
        'changes' => 'array',
    ];

    /**
     * Желание, к которому относится запись истории.
     */
    public function wish()
    {
        return $this->belongsTo(Wish::class);
    }

    /**
     * Пользователь, совершивший действие.
     */
    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
