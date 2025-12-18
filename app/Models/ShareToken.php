<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Str;

/**
 * Модель для хранения share-ссылок.
 * Каждая ссылка уникальна, может быть отозвана и содержит метаданные.
 */
class ShareToken extends Model
{
    use HasFactory, HasUuids;

    protected $table = 'share_tokens';
    protected $keyType = 'string';
    public $incrementing = false;

    // Типы сущностей для шаринга
    public const ENTITY_WISH = 'wish';
    public const ENTITY_WISHLIST = 'wishlist';
    public const ENTITY_SHOPPING_LIST = 'shopping_list';

    public const ENTITY_TYPES = [
        self::ENTITY_WISH,
        self::ENTITY_WISHLIST,
        self::ENTITY_SHOPPING_LIST,
    ];

    // Типы доступа
    public const ACCESS_PUBLIC = 'public';
    public const ACCESS_BY_LINK = 'by_link';
    public const ACCESS_FRIENDS = 'friends';

    public const ACCESS_TYPES = [
        self::ACCESS_PUBLIC,
        self::ACCESS_BY_LINK,
        self::ACCESS_FRIENDS,
    ];

    protected $fillable = [
        'share_token',
        'entity_type',
        'entity_id',
        'access_type',
        'role',
        'title',
        'description',
        'preview_image_url',
        'created_by',
        'expires_at',
        'revoked_at',
    ];

    protected $casts = [
        'expires_at' => 'datetime',
        'revoked_at' => 'datetime',
    ];

    /**
     * Генерация уникального токена при создании.
     */
    protected static function booted(): void
    {
        static::creating(function (ShareToken $model) {
            if (empty($model->share_token)) {
                $model->share_token = self::generateUniqueToken();
            }
        });
    }

    /**
     * Генерирует уникальный токен.
     */
    public static function generateUniqueToken(): string
    {
        do {
            $token = Str::random(32);
        } while (self::where('share_token', $token)->exists());

        return $token;
    }

    /**
     * Создатель ссылки.
     */
    public function creator()
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    /**
     * Проверяет, активна ли ссылка.
     */
    public function isActive(): bool
    {
        // Отозвана
        if ($this->revoked_at !== null) {
            return false;
        }

        // Истекла
        if ($this->expires_at !== null && $this->expires_at->isPast()) {
            return false;
        }

        return true;
    }

    /**
     * Проверяет, отозвана ли ссылка.
     */
    public function isRevoked(): bool
    {
        return $this->revoked_at !== null;
    }

    /**
     * Отзывает ссылку.
     */
    public function revoke(): bool
    {
        $this->revoked_at = now();
        return $this->save();
    }

    /**
     * Получает связанную сущность.
     */
    public function getEntity(): ?Model
    {
        return match ($this->entity_type) {
            self::ENTITY_WISH => Wish::find($this->entity_id),
            self::ENTITY_WISHLIST => Wishlist::find($this->entity_id),
            self::ENTITY_SHOPPING_LIST => ShoppingList::find($this->entity_id),
            default => null,
        };
    }

    /**
     * Scope для активных ссылок.
     */
    public function scopeActive($query)
    {
        return $query->whereNull('revoked_at')
            ->where(function ($q) {
                $q->whereNull('expires_at')
                    ->orWhere('expires_at', '>', now());
            });
    }

    /**
     * Scope для поиска по токену.
     */
    public function scopeByToken($query, string $token)
    {
        return $query->where('share_token', $token);
    }

    /**
     * Scope для поиска по сущности.
     */
    public function scopeForEntity($query, string $entityType, string $entityId)
    {
        return $query->where('entity_type', $entityType)
            ->where('entity_id', $entityId);
    }

    /**
     * Формирует полный URL для шаринга.
     */
    public function getShareUrl(): string
    {
        $baseUrl = rtrim((string) config('sharing.share_base_url'), '/');
        return $baseUrl . '/s/' . $this->share_token;
    }

    /**
     * Формирует deeplink.
     */
    public function getDeeplink(): string
    {
        $scheme = (string) config('sharing.deep_link_scheme', 'chtohochu');
        return $scheme . '://s/' . $this->share_token;
    }
}
