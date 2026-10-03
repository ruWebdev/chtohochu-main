<?php

namespace App\Models;

use Database\Factories\ShoppingItemFactory;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ShoppingItem extends Model
{
    /** @use HasFactory<ShoppingItemFactory> */
    use HasFactory, HasUuids;

    /**
     * Первичный ключ как строка UUID и без автоинкремента.
     */
    protected $keyType = 'string';

    public $incrementing = false;

    /**
     * The attributes that are mass assignable.
     *
     * list_id задаётся связью $list->items()->create(), а не
     * из request — в request rules его нет.
     *
     * @var list<string>
     */
    protected $fillable = [
        'id',
        'list_id',
        'title',
        'quantity',
        'is_checked',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'quantity' => 'integer',
            'is_checked' => 'boolean',
        ];
    }

    /**
     * Список, которому принадлежит позиция.
     */
    public function list(): BelongsTo
    {
        return $this->belongsTo(ShoppingList::class, 'list_id');
    }
}
