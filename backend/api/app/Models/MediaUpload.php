<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Одна media-загрузка: presigned PUT → confirm (ADR-015).
 *
 * `client_id` — клиентский идемпотентный ключ (строка wish_images и т.п.):
 * повторный create с тем же client_id возвращает существующий upload,
 * дубликатов объектов нет.
 */
class MediaUpload extends Model
{
    use HasFactory, HasUuids;

    protected $keyType = 'string';

    public $incrementing = false;

    protected $fillable = [
        'id',
        'user_id',
        'purpose',
        'entity_id',
        'client_id',
        'bucket',
        'object_key',
        'content_type',
        'declared_size',
        'status',
        'remote_url',
        'expires_at',
        'uploaded_at',
    ];

    protected function casts(): array
    {
        return [
            'declared_size' => 'integer',
            'expires_at' => 'datetime',
            'uploaded_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function isExpired(): bool
    {
        return $this->expires_at->isPast();
    }
}
