<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Модель состояния индикаторов bottom navigation bar.
 * Хранит флаги наличия непрочитанных изменений по разделам.
 * 
 * @property string $id
 * @property string $user_id
 * @property bool $wishlist Индикатор раздела ЧтоХочу
 * @property bool $purchases Индикатор раздела Покупки
 * @property bool $friends Индикатор раздела Друзья
 * @property \Carbon\Carbon $created_at
 * @property \Carbon\Carbon $updated_at
 */
class BottomNavBadge extends Model
{
    use HasUuids;

    protected $table = 'bottom_nav_badges';

    protected $keyType = 'string';
    public $incrementing = false;

    protected $fillable = [
        'user_id',
        'wishlist',
        'purchases',
        'friends',
    ];

    protected function casts(): array
    {
        return [
            'wishlist' => 'boolean',
            'purchases' => 'boolean',
            'friends' => 'boolean',
        ];
    }

    /**
     * Константы идентификаторов экранов для согласования с фронтендом.
     */
    public const SCREEN_WISHLIST = 'wishlist';
    public const SCREEN_PURCHASES = 'purchases';
    public const SCREEN_FRIENDS = 'friends';

    /**
     * Допустимые идентификаторы экранов.
     */
    public const VALID_SCREENS = [
        self::SCREEN_WISHLIST,
        self::SCREEN_PURCHASES,
        self::SCREEN_FRIENDS,
    ];

    /**
     * Связь с пользователем.
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Получить или создать запись для пользователя.
     */
    public static function getOrCreateForUser(string $userId): self
    {
        return self::firstOrCreate(
            ['user_id' => $userId],
            [
                'wishlist' => false,
                'purchases' => false,
                'friends' => false,
            ]
        );
    }

    /**
     * Установить индикатор для указанного экрана.
     */
    public function setBadge(string $screen, bool $value = true): bool
    {
        if (!in_array($screen, self::VALID_SCREENS, true)) {
            return false;
        }

        $this->{$screen} = $value;
        return $this->save();
    }

    /**
     * Сбросить индикатор для указанного экрана.
     */
    public function clearBadge(string $screen): bool
    {
        return $this->setBadge($screen, false);
    }

    /**
     * Получить состояние всех индикаторов в виде массива.
     */
    public function toStateArray(): array
    {
        return [
            'wishlist' => $this->wishlist,
            'purchases' => $this->purchases,
            'friends' => $this->friends,
        ];
    }
}
