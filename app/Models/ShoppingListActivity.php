<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ShoppingListActivity extends Model
{
    use HasFactory, HasUuids;

    protected $table = 'shopping_list_activities';
    protected $keyType = 'string';
    public $incrementing = false;

    /**
     * @var list<string>
     */
    protected $fillable = [
        'shopping_list_id',
        'user_id',
        'action',
        'data',
    ];

    /**
     * @var array<string, string>
     */
    protected $casts = [
        'data' => 'array',
    ];

    public function shoppingList()
    {
        return $this->belongsTo(ShoppingList::class);
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
