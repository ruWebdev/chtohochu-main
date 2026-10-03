<?php

namespace App\Models;

use Database\Factories\ShoppingListFactory;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

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
}
