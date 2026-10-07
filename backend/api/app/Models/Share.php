<?php

namespace App\Models;

use Database\Factories\ShareFactory;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\MorphTo;

class Share extends Model
{
    /** @use HasFactory<ShareFactory> */
    use HasFactory, HasUuids;

    /**
     * Первичный ключ как строка UUID и без автоинкремента.
     */
    protected $keyType = 'string';

    public $incrementing = false;

    /**
     * The attributes that are mass assignable.
     *
     * token генерируется только сервером и не принимается из
     * request — клиент не задаёт capability-идентификатор.
     *
     * @var list<string>
     */
    protected $fillable = [
        'id',
        'owner_id',
        'shareable_type',
        'shareable_id',
        'token',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'revoked_at' => 'datetime',
            'expires_at' => 'datetime',
        ];
    }

    /**
     * Владелец share — авторизованный пользователь, создавший
     * ссылку. Только он может её отозвать.
     */
    public function owner(): BelongsTo
    {
        return $this->belongsTo(User::class, 'owner_id');
    }

    /**
     * Объект шеринга: Wish | WishList.
     */
    public function shareable(): MorphTo
    {
        return $this->morphTo();
    }

    /**
     * Активные (не отозванные) shares.
     */
    public function scopeActive(Builder $query): Builder
    {
        return $query->whereNull('revoked_at');
    }
}
