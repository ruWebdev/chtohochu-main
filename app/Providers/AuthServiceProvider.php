<?php

namespace App\Providers;

use App\Models\ShoppingList;
use App\Models\Wishlist;
use App\Models\Wish;
use App\Policies\ShoppingListPolicy;
use App\Policies\WishlistPolicy;
use App\Policies\WishPolicy;
use Illuminate\Foundation\Support\Providers\AuthServiceProvider as ServiceProvider;

class AuthServiceProvider extends ServiceProvider
{
    /**
     * The model to policy mappings for the application.
     *
     * @var array<class-string, class-string>
     */
    protected $policies = [
        ShoppingList::class => ShoppingListPolicy::class,
        Wishlist::class => WishlistPolicy::class,
        Wish::class => WishPolicy::class,
    ];

    /**
     * Register any authentication / authorization services.
     */
    public function boot(): void
    {
        $this->registerPolicies();
    }
}
