<?php

namespace App\Providers;

use App\Events\ShoppingList\ShoppingListItemCreated;
use App\Events\ShoppingList\ShoppingListItemUpdated;
use App\Events\User\FriendRequestAccepted;
use App\Events\User\FriendRequestSent;
use App\Events\User\UserTaggedInList;
use App\Events\User\UserTaggedInShoppingList;
use App\Events\Wish\WishUpdated;
use App\Events\Wishlist\WishlistItemAdded;
use App\Events\Wishlist\WishlistParticipantAdded;
use App\Listeners\BottomNavBadgeListener;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Vite;
use Illuminate\Support\ServiceProvider;
use SocialiteProviders\Manager\SocialiteWasCalled;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        Vite::prefetch(concurrency: 3);

        Event::listen(function (SocialiteWasCalled $event) {
            $event->extendSocialite('vkontakte', \SocialiteProviders\VKontakte\Provider::class);
        });

        Event::listen(function (SocialiteWasCalled $event) {
            $event->extendSocialite('yandex', \SocialiteProviders\Yandex\Provider::class);
        });

        // Регистрация слушателей для индикаторов bottom navigation bar
        $this->registerBottomNavBadgeListeners();
    }

    /**
     * Регистрация слушателей событий для индикаторов bottom navigation bar.
     */
    private function registerBottomNavBadgeListeners(): void
    {
        // Wishlist события
        Event::listen(WishlistItemAdded::class, [BottomNavBadgeListener::class, 'handleWishlistItemAdded']);
        Event::listen(WishUpdated::class, [BottomNavBadgeListener::class, 'handleWishUpdated']);
        Event::listen(WishlistParticipantAdded::class, [BottomNavBadgeListener::class, 'handleWishlistParticipantAdded']);
        Event::listen(UserTaggedInList::class, [BottomNavBadgeListener::class, 'handleUserTaggedInList']);

        // Shopping list события
        Event::listen(ShoppingListItemCreated::class, [BottomNavBadgeListener::class, 'handleShoppingListItemCreated']);
        Event::listen(ShoppingListItemUpdated::class, [BottomNavBadgeListener::class, 'handleShoppingListItemUpdated']);
        Event::listen(UserTaggedInShoppingList::class, [BottomNavBadgeListener::class, 'handleUserTaggedInShoppingList']);

        // Friends события
        Event::listen(FriendRequestSent::class, [BottomNavBadgeListener::class, 'handleFriendRequestSent']);
        Event::listen(FriendRequestAccepted::class, [BottomNavBadgeListener::class, 'handleFriendRequestAccepted']);
    }
}
