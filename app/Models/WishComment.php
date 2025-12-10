<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * Модель комментария к желанию.
 */
class WishComment extends Model
{
    use HasFactory, HasUuids;

    protected $table = 'wish_comments';
    protected $keyType = 'string';
    public $incrementing = false;

    protected $fillable = [
        'wish_id',
        'user_id',
        'text',
    ];

    /**
     * Желание, к которому относится комментарий.
     */
    public function wish()
    {
        return $this->belongsTo(Wish::class);
    }

    /**
     * Автор комментария.
     */
    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
