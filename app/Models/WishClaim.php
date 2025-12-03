<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class WishClaim extends Model
{
    use HasFactory, HasUuids;

    protected $table = 'wish_claims';
    protected $keyType = 'string';
    public $incrementing = false;

    protected $fillable = [
        'wish_id',
        'user_id',
        'claimed_at',
        'is_secret',
    ];

    protected $casts = [
        'claimed_at' => 'datetime',
        'is_secret' => 'bool',
    ];

    public function wish()
    {
        return $this->belongsTo(Wish::class);
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
