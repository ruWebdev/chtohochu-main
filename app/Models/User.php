<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Support\Facades\Storage;
use Spatie\Permission\Traits\HasRoles;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    /** @use HasFactory<\Database\Factories\UserFactory> */
    use HasApiTokens, HasFactory, Notifiable, HasUuids, HasRoles;

    /**
     * Первичный ключ как строка UUID и без автоинкремента.
     */
    protected $keyType = 'string';
    public $incrementing = false;

    /**
     * The attributes that are mass assignable.
     *
     * @var list<string>
     */
    protected $fillable = [
        'name',
        'username',
        'email',
        'password',
        'about',
        'gender',
        'age',
        'city',
        'avatar',
        'vk_id',
    ];

    /**
     * The attributes that should be hidden for serialization.
     *
     * @var list<string>
     */
    protected $hidden = [
        'password',
        'remember_token',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'age' => 'integer',
            'birth_date' => 'date',
        ];
    }

    public function getAvatarAttribute($value): ?string
    {
        if (! $value) {
            return null;
        }

        return Storage::disk('public')->url($value);
    }

    /**
     * Отношение: FCM-токены устройств пользователя.
     */
    public function deviceTokens()
    {
        return $this->hasMany(DeviceToken::class);
    }

    /**
     * Канал маршрутизации уведомлений для FCM.
     * Должен вернуть массив токенов устройств.
     */
    public function routeNotificationForFcm(): array
    {
        return $this->deviceTokens()
            ->pluck('token')
            ->filter()
            ->unique()
            ->values()
            ->all();
    }

    /**
     * Списки покупок, где пользователь является владельцем.
     */
    public function shoppingListsOwned()
    {
        return $this->hasMany(ShoppingList::class, 'owner_id');
    }

    /**
     * Совместные списки покупок, в которых пользователь является участником.
     */
    public function shoppingListsShared()
    {
        return $this->belongsToMany(ShoppingList::class, 'shopping_list_user')
            ->withTimestamps();
    }

    /**
     * Списки желаний пользователя.
     */
    public function wishlists()
    {
        return $this->hasMany(Wishlist::class, 'owner_id');
    }

    /**
     * Совместные списки желаний, в которых пользователь является участником.
     */
    public function wishlistsShared()
    {
        return $this->belongsToMany(Wishlist::class, 'wishlist_user')
            ->withTimestamps();
    }

    /**
     * Желания, в которых пользователь участвует.
     */
    public function wishesParticipating()
    {
        return $this->belongsToMany(Wish::class, 'wish_user')
            ->withTimestamps();
    }

    /**
     * Настройки уведомлений пользователя.
     */
    public function notificationSetting()
    {
        return $this->hasOne(NotificationSetting::class);
    }

    /**
     * Заявки в друзья, отправленные пользователем.
     */
    public function friendshipsSent()
    {
        return $this->hasMany(Friendship::class, 'requester_id');
    }

    /**
     * Заявки в друзья, полученные пользователем.
     */
    public function friendshipsReceived()
    {
        return $this->hasMany(Friendship::class, 'addressee_id');
    }

    /**
     * Список друзей пользователя.
     */
    public function friends()
    {
        $acceptedSent = Friendship::query()
            ->where('requester_id', $this->id)
            ->where('status', Friendship::STATUS_ACCEPTED)
            ->pluck('addressee_id');

        $acceptedReceived = Friendship::query()
            ->where('addressee_id', $this->id)
            ->where('status', Friendship::STATUS_ACCEPTED)
            ->pluck('requester_id');

        $ids = $acceptedSent->merge($acceptedReceived)
            ->unique()
            ->values()
            ->all();

        if ($ids === []) {
            return static::query()
                ->whereKey([])
                ->get();
        }

        return static::query()
            ->whereIn('id', $ids)
            ->get();
    }
}
