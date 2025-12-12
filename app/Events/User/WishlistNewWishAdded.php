<?php

namespace App\Events\User;

use App\Models\User;
use App\Models\Wish;
use App\Models\Wishlist;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class WishlistNewWishAdded implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public User $user,
        public Wishlist $wishlist,
        public Wish $wish,
        public User $author,
    ) {}

    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('user.' . $this->user->id),
        ];
    }

    public function broadcastAs(): string
    {
        return 'WishlistNewWishAdded';
    }

    public function broadcastWith(): array
    {
        return [
            'listId' => $this->wishlist->id,
            'listName' => $this->wishlist->name,
            'wishId' => $this->wish->id,
            'wishName' => $this->wish->name,
            'authorId' => $this->author->id,
            'authorName' => $this->author->name,
            'timestamp' => now()->toISOString(),
        ];
    }
}
