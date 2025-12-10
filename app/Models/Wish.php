<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Wish extends Model
{
    use HasFactory, HasUuids;

    protected $table = 'wishes';
    protected $keyType = 'string';
    public $incrementing = false;

    public const VISIBILITY_PERSONAL = 'personal';
    public const VISIBILITY_LINK = 'link';
    public const VISIBILITY_PUBLIC = 'public';

    public const VISIBILITIES = [
        self::VISIBILITY_PERSONAL,
        self::VISIBILITY_LINK,
        self::VISIBILITY_PUBLIC,
    ];

    public const NECESSITY_LATER = 'later';
    public const NECESSITY_NEED = 'need';
    public const NECESSITY_URGENT = 'urgent';

    public const NECESSITIES = [
        self::NECESSITY_LATER,
        self::NECESSITY_NEED,
        self::NECESSITY_URGENT,
    ];

    public const STATUS_FULFILLED = 'fulfilled';
    public const STATUS_NOT_FULFILLED = 'not_fulfilled';
    public const STATUS_IN_PROGRESS = 'in_progress';

    public const STATUSES = [
        self::STATUS_FULFILLED,
        self::STATUS_NOT_FULFILLED,
        self::STATUS_IN_PROGRESS,
    ];

    public const PRIORITY_LOW = 'low';
    public const PRIORITY_MEDIUM = 'medium';
    public const PRIORITY_HIGH = 'high';

    public const PRIORITIES = [
        self::PRIORITY_LOW,
        self::PRIORITY_MEDIUM,
        self::PRIORITY_HIGH,
    ];

    /**
     * Атрибуты, доступные для массового присвоения.
     *
     * @var list<string>
     */
    protected $fillable = [
        'wishlist_id',
        'owner_id',
        'name',
        'visibility',
        'images',
        'necessity',
        'description',
        'url',
        'desired_price',
        'price_min',
        'price_max',
        'priority',
        'tags',
        'reminder_enabled',
        'reminder_at',
        'deadline_at',
        'status',
        'executor_user_id',
        'hide_price',
        'allow_claiming',
        'sort_index',
        'in_progress',
    ];

    /**
     * Приведения типов атрибутов.
     *
     * @var array<string, string>
     */
    protected $casts = [
        'images' => 'array',
        'desired_price' => 'decimal:2',
        'price_min' => 'decimal:2',
        'price_max' => 'decimal:2',
        'tags' => 'array',
        'reminder_enabled' => 'bool',
        'reminder_at' => 'datetime',
        'deadline_at' => 'datetime',
        'hide_price' => 'bool',
        'allow_claiming' => 'bool',
        'sort_index' => 'integer',
        'in_progress' => 'bool',
    ];

    /**
     * Список желаний, к которому относится это желание.
     */
    public function wishlist()
    {
        return $this->belongsTo(Wishlist::class);
    }

    /**
     * Владелец желания.
     */
    public function owner()
    {
        return $this->belongsTo(User::class, 'owner_id');
    }

    /**
     * Участники этого желания.
     */
    public function participants()
    {
        return $this->belongsToMany(User::class, 'wish_user')
            ->withTimestamps();
    }

    public function executor()
    {
        return $this->belongsTo(User::class, 'executor_user_id');
    }

    public function claimers()
    {
        return $this->hasMany(WishClaim::class);
    }
}
