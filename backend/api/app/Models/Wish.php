<?php

namespace App\Models;

use Database\Factories\WishFactory;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Wish extends Model
{
    /** @use HasFactory<WishFactory> */
    use HasFactory, HasUuids;

    /**
     * Первичный ключ как строка UUID и без автоинкремента.
     */
    protected $keyType = 'string';

    public $incrementing = false;

    /**
     * The attributes that are mass assignable.
     *
     * Защита от подмены владельца — на уровне Form Request:
     * в create() попадает только $request->validated(), а
     * owner_id задаётся связью $user->wishes()->create().
     *
     * @var list<string>
     */
    protected $fillable = [
        'id',
        'owner_id',
        'title',
        'description',
        'price',
        'link',
        'image_url',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'price' => 'integer',
        ];
    }

    /**
     * Владелец желания.
     */
    public function owner(): BelongsTo
    {
        return $this->belongsTo(User::class, 'owner_id');
    }
}
