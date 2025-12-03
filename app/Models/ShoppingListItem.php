<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ShoppingListItem extends Model
{
    use HasFactory, HasUuids;

    protected $table = 'shopping_list_items';
    protected $keyType = 'string';
    public $incrementing = false;

    /**
     * Атрибуты, доступные для массового присвоения.
     *
     * @var list<string>
     */
    protected $fillable = [
        'shopping_list_id',
        'name',
        'image_url',
        'quantity',
        'unit',
        'priority',
        'is_purchased',
        'sort_index',
        'assigned_user_id',
        'completed_by',
        'completed_at',
        'event_date',
        'note',
    ];

    /**
     * Приведения типов атрибутов.
     *
     * @var array<string, string>
     */
    protected $casts = [
        'is_purchased' => 'boolean',
        'sort_index' => 'integer',
        'quantity' => 'integer',
        'completed_at' => 'datetime',
        'event_date' => 'date',
    ];

    /**
     * Список покупок, к которому относится пункт.
     */
    public function shoppingList()
    {
        return $this->belongsTo(ShoppingList::class);
    }

    public function assignedUser()
    {
        return $this->belongsTo(User::class, 'assigned_user_id');
    }

    public function completedBy()
    {
        return $this->belongsTo(User::class, 'completed_by');
    }
}
