<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ShareToken extends Model
{
    use HasFactory, HasUuids;

    protected $table = 'share_tokens';
    protected $keyType = 'string';
    public $incrementing = false;

    protected $fillable = [
        'entity_type',
        'entity_id',
        'access_type',
        'role',
        'created_by',
        'expires_at',
    ];

    protected $casts = [
        'expires_at' => 'datetime',
    ];

    public function creator()
    {
        return $this->belongsTo(User::class, 'created_by');
    }
}
