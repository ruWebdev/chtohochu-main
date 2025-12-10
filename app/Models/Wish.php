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
        'private_notes',
        'checklist',
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
        'allow_comments',
        'allow_sharing',
        'purchase_receipt',
        'purchase_date',
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
        'checklist' => 'array',
        'desired_price' => 'decimal:2',
        'price_min' => 'decimal:2',
        'price_max' => 'decimal:2',
        'tags' => 'array',
        'reminder_enabled' => 'bool',
        'reminder_at' => 'datetime',
        'deadline_at' => 'datetime',
        'purchase_date' => 'datetime',
        'hide_price' => 'bool',
        'allow_claiming' => 'bool',
        'allow_comments' => 'bool',
        'allow_sharing' => 'bool',
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

    /**
     * Комментарии к желанию.
     */
    public function comments()
    {
        return $this->hasMany(WishComment::class)->orderBy('created_at', 'desc');
    }

    /**
     * Лайки желания.
     */
    public function likes()
    {
        return $this->hasMany(WishLike::class);
    }

    /**
     * История изменений желания.
     */
    public function history()
    {
        return $this->hasMany(WishHistory::class)->orderBy('created_at', 'desc');
    }

    /**
     * Прикреплённые файлы.
     */
    public function attachments()
    {
        return $this->hasMany(WishAttachment::class);
    }

    /**
     * Проверяет, лайкнул ли пользователь это желание.
     */
    public function isLikedByUser(?User $user): bool
    {
        if (!$user) {
            return false;
        }
        return $this->likes()->where('user_id', $user->id)->exists();
    }

    /**
     * Получает права доступа для пользователя.
     */
    public function getPermissionsForUser(?User $user): array
    {
        $isOwner = $user && $this->owner_id === $user->id;
        $isAuthenticated = $user !== null;

        // Проверяем, является ли пользователь редактором списка
        $isEditor = false;
        if ($user && $this->wishlist) {
            $participant = $this->wishlist->participants()->where('user_id', $user->id)->first();
            $isEditor = $participant && in_array($participant->pivot->role ?? 'viewer', ['editor', 'admin']);
        }

        return [
            'can_edit' => $isOwner || $isEditor,
            'can_delete' => $isOwner,
            'can_comment' => $isAuthenticated && ($this->allow_comments ?? true),
            'can_like' => $isAuthenticated,
            'can_claim' => $isAuthenticated && !$isOwner && ($this->allow_claiming ?? true),
            'can_share' => $this->allow_sharing ?? true,
            'can_add_to_list' => $isAuthenticated && !$isOwner,
            'can_view_private_notes' => $isOwner,
        ];
    }
}
