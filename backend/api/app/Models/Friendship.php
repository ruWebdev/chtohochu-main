<?php

namespace App\Models;

use Database\Factories\FriendshipFactory;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Дружба между двумя пользователями. Симметрична:
 * одна запись на пару, user_id < friend_id.
 */
class Friendship extends Model
{
    /** @use HasFactory<FriendshipFactory> */
    use HasFactory, HasUuids;

    /**
     * Первичный ключ как строка UUID и без автоинкремента.
     */
    protected $keyType = 'string';

    public $incrementing = false;

    public const STATUS_ACCEPTED = 'accepted';

    /**
     * The attributes that are mass assignable.
     *
     * @var list<string>
     */
    protected $fillable = [
        'user_id',
        'friend_id',
        'initiator_id',
        'status',
    ];

    /**
     * Нормализация пары: меньший id → user_id.
     *
     * @return array{0: string, 1: string}
     */
    public static function normalizePair(string $a, string $b): array
    {
        return strcmp($a, $b) < 0 ? [$a, $b] : [$b, $a];
    }

    /**
     * Существующая (accepted) дружба между двумя пользователями.
     */
    public static function between(string $a, string $b): ?self
    {
        [$userId, $friendId] = self::normalizePair($a, $b);

        return static::query()
            ->where('user_id', $userId)
            ->where('friend_id', $friendId)
            ->where('status', self::STATUS_ACCEPTED)
            ->first();
    }

    /**
     * Создать дружбу между двумя пользователями.
     */
    public static function createBetween(User $initiator, User $friend): self
    {
        [$userId, $friendId] = self::normalizePair($initiator->id, $friend->id);

        return static::create([
            'user_id' => $userId,
            'friend_id' => $friendId,
            'initiator_id' => $initiator->id,
            'status' => self::STATUS_ACCEPTED,
        ]);
    }

    /**
     * Пользователь с меньшим id в паре.
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    /**
     * Пользователь с большим id в паре.
     */
    public function friend(): BelongsTo
    {
        return $this->belongsTo(User::class, 'friend_id');
    }

    /**
     * Кто инициировал дружбу.
     */
    public function initiator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'initiator_id');
    }

    /**
     * Участвует ли пользователь в этой дружбе.
     */
    public function involves(User $user): bool
    {
        return $this->user_id === $user->id || $this->friend_id === $user->id;
    }
}
