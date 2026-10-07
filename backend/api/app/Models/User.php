<?php

namespace App\Models;

use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Casts\Attribute;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Illuminate\Support\Collection;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, HasUuids, Notifiable;

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
        'avatar_url',
        'vk_id',
        'yandex_id',
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
        ];
    }

    /**
     * Email хранится в нижнем регистре — сравнение
     * case-insensitive без citext.
     */
    protected function email(): Attribute
    {
        return Attribute::make(
            set: fn (?string $value) => $value === null ? null : mb_strtolower($value),
        );
    }

    /**
     * Желания пользователя.
     */
    public function wishes(): HasMany
    {
        return $this->hasMany(Wish::class, 'owner_id');
    }

    /**
     * Списки покупок пользователя.
     */
    public function shoppingLists(): HasMany
    {
        return $this->hasMany(ShoppingList::class, 'owner_id');
    }

    /**
     * Списки желаний пользователя (группировка wishes).
     */
    public function wishLists(): HasMany
    {
        return $this->hasMany(WishList::class, 'owner_id');
    }

    /**
     * Друзья пользователя. Дружба симметрична — одна запись
     * в friendships с нормализованной парой (user_id < friend_id).
     *
     * Возвращает query builder (не Relation): симметричная пара
     * не выражается одним belongsToMany.
     */
    public function friends(): Builder
    {
        return User::query()->whereExists(function ($q) {
            $q->selectRaw('1')
                ->from('friendships')
                ->where('status', Friendship::STATUS_ACCEPTED)
                ->where(function ($w) {
                    $w->where(fn ($x) => $x->where('user_id', $this->id)->whereColumn('friend_id', 'users.id'))
                        ->orWhere(fn ($x) => $x->where('friend_id', $this->id)->whereColumn('user_id', 'users.id'));
                });
        });
    }

    /**
     * Id друзей пользователя (мемоизируется на время жизни
     * объекта — search отдаёт до 20 пользователей с is_friend).
     */
    public function friendIds(): Collection
    {
        return $this->friendIdsCache ??= $this->friends()->pluck('users.id');
    }

    /**
     * Есть ли accepted-дружба между пользователями.
     */
    public function isFriendWith(User $other): bool
    {
        return $this->friendIds()->contains($other->id);
    }

    /**
     * @var Collection<int, string>|null
     */
    private ?Collection $friendIdsCache = null;
}
