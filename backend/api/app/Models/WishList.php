<?php

namespace App\Models;

use Database\Factories\WishListFactory;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class WishList extends Model
{
    /** @use HasFactory<WishListFactory> */
    use HasFactory, HasUuids, SoftDeletes;

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
     * Желания, входящие в список (wishes.list_id).
     */
    public function wishes(): HasMany
    {
        return $this->hasMany(Wish::class, 'list_id');
    }
}
