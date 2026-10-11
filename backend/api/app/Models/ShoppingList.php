<?php

namespace App\Models;

use Database\Factories\ShoppingListFactory;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Collection;

class ShoppingList extends Model
{
    /** @use HasFactory<ShoppingListFactory> */
    use HasFactory, HasUuids;

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
        'id',
        'owner_id',
        'title',
    ];

    /**
     * Владелец списка.
     */
    public function owner(): BelongsTo
    {
        return $this->belongsTo(User::class, 'owner_id');
    }

    /**
     * Позиции списка в порядке добавления.
     */
    public function items(): HasMany
    {
        return $this->hasMany(ShoppingItem::class, 'list_id')->oldest('created_at');
    }

    /**
     * Участники списка (без владельца — он участник неявно
     * через owner_id и в pivot не дублируется).
     */
    public function members(): BelongsToMany
    {
        return $this
            ->belongsToMany(User::class, 'shopping_list_members', 'list_id', 'user_id')
            ->withTimestamps();
    }

    /**
     * Участник ли пользователь: владелец или member.
     */
    public function hasMember(User $user): bool
    {
        if ($this->owner_id === $user->id) {
            return true;
        }
        $members = $this->relationLoaded('members')
            ? $this->members
            : $this->members()->get();

        return $members->contains('id', $user->id);
    }

    /**
     * Все участники: владелец + members. Для broadcast fan-out
     * и сериализации participants.
     *
     * @return Collection<int, User>
     */
    public function participants(): Collection
    {
        $members = $this->relationLoaded('members')
            ? $this->members
            : $this->members()->get();

        return collect([$this->owner])->merge($members)->filter();
    }

    /**
     * Id всех участников (owner + members) для broadcast fan-out.
     *
     * @return list<string>
     */
    public function participantIds(): array
    {
        return $this->participants()->pluck('id')->all();
    }

    /**
     * Следующая ревизия сущности — вызывать в транзакции мутации.
     */
    public function bumpRevision(): int
    {
        $this->increment('revision');

        return (int) $this->revision;
    }
}
