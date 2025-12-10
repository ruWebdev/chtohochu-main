<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * Модель лайка желания.
 */
class WishLike extends Model
{
    use HasFactory, HasUuids;

    protected $table = 'wish_likes';
    protected $keyType = 'string';
    public $incrementing = false;

    // Только created_at, без updated_at
    const UPDATED_AT = null;

    protected $fillable = [
        'wish_id',
        'user_id',
    ];

    /**
     * Желание, которое лайкнули.
     */
    public function wish()
    {
        return $this->belongsTo(Wish::class);
    }

    /**
     * Пользователь, поставивший лайк.
     */
    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
