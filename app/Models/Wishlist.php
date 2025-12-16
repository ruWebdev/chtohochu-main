<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Wishlist extends Model
{
    use HasFactory, HasUuids;

    protected $table = 'wishlists';
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

    public const STATUS_NEW = 'new';
    public const STATUS_IN_PROGRESS = 'in_progress';
    public const STATUS_CLOSED = 'closed';

    public const STATUSES = [
        self::STATUS_NEW,
        self::STATUS_IN_PROGRESS,
        self::STATUS_CLOSED,
    ];

    public const SORT_CREATED_AT = 'created_at';
    public const SORT_NAME = 'name';
    public const SORT_NECESSITY = 'necessity';

    public const WISHES_SORT_OPTIONS = [
        self::SORT_CREATED_AT,
        self::SORT_NAME,
        self::SORT_NECESSITY,
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
        'visibility',
        'status',
        'avatar',
        'card_color',
        'wishes_sort',
        'tags',
        'reminder_enabled',
        'reminder_at',
        'allow_claiming',
        'show_claimers',
    ];

    /**
     * Приведения типов атрибутов.
     *
     * @var array<string, string>
     */
    protected $casts = [
        'tags' => 'array',
        'reminder_enabled' => 'bool',
        'reminder_at' => 'datetime',
    ];

    /**
     * Владелец списка желаний.
     */
    public function owner()
    {
        return $this->belongsTo(User::class, 'owner_id');
    }

    /**
     * Желания, входящие в этот список.
     */
    public function wishes()
    {
        return $this->hasMany(Wish::class);
    }

    /**
     * Участники списка желаний (кроме владельца).
     */
    public function participants()
    {
        return $this->belongsToMany(User::class, 'wishlist_user')
            ->withPivot('role')
            ->withTimestamps();
    }

    /**
     * Пользователи, добавившие этот список желаний в избранное.
     */
    public function favorites()
    {
        return $this->belongsToMany(User::class, 'wishlist_favorites')
            ->withTimestamps();
    }

    public function isFavoriteForUser(?User $user): bool
    {
        if (! $user) {
            return false;
        }

        if ($this->relationLoaded('favorites')) {
            return $this->favorites->contains('id', $user->id);
        }

        return $this->favorites()
            ->where('user_id', $user->id)
            ->exists();
    }
}
