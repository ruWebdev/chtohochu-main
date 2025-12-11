<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ShoppingList extends Model
{
    use HasFactory, HasUuids;

    protected $table = 'shopping_lists';
    protected $keyType = 'string';
    public $incrementing = false;

    public const STATUS_NEW = 'new';
    public const STATUS_IN_PROGRESS = 'in_progress';
    public const STATUS_CLOSED = 'closed';

    public const STATUSES = [
        self::STATUS_NEW,
        self::STATUS_IN_PROGRESS,
        self::STATUS_CLOSED,
    ];

    /**
     * Атрибуты, доступные для массового присвоения.
     *
     * @var list<string>
     */
    protected $fillable = [
        'owner_id',
        'name',
        'description',
        'is_shared',
        'status',
        'avatar',
        'card_color',
        'notifications_enabled',
        'deadline_at',
        'event_name',
        'sort_order',
    ];

    /**
     * Приведения типов атрибутов.
     *
     * @var array<string, string>
     */
    protected $casts = [
        'is_shared' => 'boolean',
        'notifications_enabled' => 'boolean',
        'deadline_at' => 'datetime',
        'sort_order' => 'integer',
    ];

    /**
     * Владелец списка покупок.
     */
    public function owner()
    {
        return $this->belongsTo(User::class, 'owner_id');
    }

    /**
     * Пункты этого списка.
     */
    public function items()
    {
        return $this->hasMany(ShoppingListItem::class);
    }

    /**
     * Участники совместного списка (кроме владельца).
     */
    public function participants()
    {
        return $this->belongsToMany(User::class, 'shopping_list_user')
            ->withTimestamps();
    }

    public function activities()
    {
        return $this->hasMany(ShoppingListActivity::class);
    }
}
