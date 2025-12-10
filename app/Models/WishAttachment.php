<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * Модель прикреплённого файла к желанию.
 */
class WishAttachment extends Model
{
    use HasFactory, HasUuids;

    protected $table = 'wish_attachments';
    protected $keyType = 'string';
    public $incrementing = false;

    protected $fillable = [
        'wish_id',
        'file_name',
        'file_url',
        'file_type',
        'file_size',
    ];

    protected $casts = [
        'file_size' => 'integer',
    ];

    /**
     * Желание, к которому прикреплён файл.
     */
    public function wish()
    {
        return $this->belongsTo(Wish::class);
    }
}
