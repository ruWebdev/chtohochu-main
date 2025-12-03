<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Friendship extends Model
{
    use HasFactory, HasUuids;

    protected $table = 'friendships';
    protected $keyType = 'string';
    public $incrementing = false;

    public const STATUS_PENDING = 'pending';
    public const STATUS_ACCEPTED = 'accepted';

    public const STATUSES = [
        self::STATUS_PENDING,
        self::STATUS_ACCEPTED,
    ];

    /**
     * Атрибуты, доступные для массового присвоения.
     *
     * @var list<string>
     */
    protected $fillable = [
        'requester_id',
        'addressee_id',
        'status',
    ];

    /**
     * Приведения типов атрибутов.
     *
     * @var array<string, string>
     */
    protected $casts = [];

    /**
     * Пользователь, который отправил заявку в друзья.
     */
    public function requester()
    {
        return $this->belongsTo(User::class, 'requester_id');
    }

    /**
     * Пользователь, который получает заявку в друзья.
     */
    public function addressee()
    {
        return $this->belongsTo(User::class, 'addressee_id');
    }
}
