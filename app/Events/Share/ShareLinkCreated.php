<?php

namespace App\Events\Share;

use App\Models\ShareToken;
use App\Models\User;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Событие создания share-ссылки.
 */
class ShareLinkCreated
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public ShareToken $shareToken,
        public User $creator
    ) {}
}
