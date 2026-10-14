<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Дополнительное изображение желания.
 *
 * Primary-изображение — `wishes.image_url`; эта модель хранит
 * только additional, упорядоченные `sort_order` (1..N). Id —
 * клиентский UUID: он же `client_id` соответствующей строки
 * media_uploads, что даёт идемпотентные PATCH и точечную
 * очистку объектов при удалении изображения.
 */
class WishImage extends Model
{
    /** @use HasFactory<\Database\Factories\WishImageFactory> */
    use HasFactory, HasUuids;

    protected $keyType = 'string';

    public $incrementing = false;

    protected $fillable = [
        'id',
        'wish_id',
        'url',
        'sort_order',
    ];

    protected function casts(): array
    {
        return [
            'sort_order' => 'integer',
        ];
    }

    public function wish(): BelongsTo
    {
        return $this->belongsTo(Wish::class);
    }
}
