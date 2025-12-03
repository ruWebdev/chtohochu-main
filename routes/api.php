<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\HealthController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\FcmTokenController;
use App\Http\Controllers\Api\ShoppingListController;
use App\Http\Controllers\Api\ShoppingListItemController;
use App\Http\Controllers\Api\WishlistController;
use App\Http\Controllers\Api\WishController;
use App\Http\Controllers\Api\FriendController;
use App\Http\Controllers\Api\UserController;
use App\Http\Controllers\Api\ProductPreviewController;
use App\Http\Controllers\Api\NotificationSettingController;
use App\Http\Controllers\Auth\VkAuthController;

Route::domain(env('APP_DOMAIN_API'))
    ->middleware(['api', 'api.segment'])
    ->group(function () {
        Route::get('/health', HealthController::class)->name('api.health');

        // Аутентификация (Sanctum)
        Route::post('/auth/register', [AuthController::class, 'register'])->name('api.auth.register');
        Route::post('/auth/login', [AuthController::class, 'login'])->name('api.auth.login');
        Route::post('/auth/vk', [VkAuthController::class, 'login'])
            ->middleware('throttle:10,1');

        Route::middleware('auth:sanctum')->group(function () {
            Route::get('/auth/me', [AuthController::class, 'me'])->name('api.auth.me');
            Route::post('/auth/logout', [AuthController::class, 'logout'])->name('api.auth.logout');
            Route::post('/auth/logout-all', [AuthController::class, 'logoutAll'])->name('api.auth.logout_all');

            Route::post('/products/preview', ProductPreviewController::class)->name('api.products.preview');

            // Настройки уведомлений
            Route::get('/notification-settings', [NotificationSettingController::class, 'show'])
                ->name('api.notification_settings.show');
            Route::put('/notification-settings', [NotificationSettingController::class, 'update'])
                ->name('api.notification_settings.update');

            // Друзья
            Route::get('/friends', [FriendController::class, 'index'])->name('api.friends.index');
            Route::post('/friends/requests', [FriendController::class, 'sendRequest'])->name('api.friends.requests.send');
            Route::get('/friends/requests/pending', [FriendController::class, 'pending'])->name('api.friends.requests.pending');
            Route::post('/friends/requests/{friendship}/accept', [FriendController::class, 'accept'])->name('api.friends.requests.accept');
            Route::post('/friends/requests/{friendship}/reject', [FriendController::class, 'reject'])->name('api.friends.requests.reject');

            // Поиск пользователей
            Route::get('/users/search', [UserController::class, 'search'])->name('api.users.search');

            // FCM токены и тестовое уведомление
            Route::post('/fcm/token', [FcmTokenController::class, 'store'])->name('api.fcm.token.store');
            Route::delete('/fcm/token', [FcmTokenController::class, 'destroy'])->name('api.fcm.token.destroy');
            Route::post('/fcm/test', [FcmTokenController::class, 'test'])->name('api.fcm.test');

            // Списки покупок
            Route::get('/shopping-lists', [ShoppingListController::class, 'index'])->name('api.shopping_lists.index');
            Route::post('/shopping-lists', [ShoppingListController::class, 'store'])->name('api.shopping_lists.store');
            Route::get('/shopping-lists/{shoppingList}', [ShoppingListController::class, 'show'])->name('api.shopping_lists.show');
            Route::patch('/shopping-lists/{shoppingList}', [ShoppingListController::class, 'update'])->name('api.shopping_lists.update');
            Route::delete('/shopping-lists/{shoppingList}', [ShoppingListController::class, 'destroy'])->name('api.shopping_lists.destroy');

            // Пункты списков покупок
            Route::get('/shopping-lists/{shoppingList}/items', [ShoppingListItemController::class, 'index'])->name('api.shopping_list_items.index');
            Route::post('/shopping-lists/{shoppingList}/items', [ShoppingListItemController::class, 'store'])->name('api.shopping_list_items.store');
            Route::patch('/shopping-lists/{shoppingList}/items/{item}', [ShoppingListItemController::class, 'update'])->name('api.shopping_list_items.update');
            Route::delete('/shopping-lists/{shoppingList}/items/{item}', [ShoppingListItemController::class, 'destroy'])->name('api.shopping_list_items.destroy');

            // Списки желаний
            Route::get('/wishlists', [WishlistController::class, 'index'])->name('api.wishlists.index');
            Route::post('/wishlists', [WishlistController::class, 'store'])->name('api.wishlists.store');
            Route::get('/wishlists/friends', [WishlistController::class, 'friends'])->name('api.wishlists.friends');
            Route::get('/wishlists/public', [WishlistController::class, 'public'])->name('api.wishlists.public');
            Route::get('/wishlists/{wishlist}', [WishlistController::class, 'show'])->name('api.wishlists.show');
            Route::put('/wishlists/{wishlist}', [WishlistController::class, 'update'])->name('api.wishlists.update');
            Route::patch('/wishlists/{wishlist}', [WishlistController::class, 'update']);
            Route::delete('/wishlists/{wishlist}', [WishlistController::class, 'destroy'])->name('api.wishlists.destroy');

            // Участники списков желаний
            Route::get('/wishlists/{wishlist}/participants', [WishlistController::class, 'participants'])->name('api.wishlists.participants.index');
            Route::post('/wishlists/{wishlist}/participants', [WishlistController::class, 'addParticipant'])->name('api.wishlists.participants.add');
            Route::delete('/wishlists/{wishlist}/participants/{user}', [WishlistController::class, 'removeParticipant'])->name('api.wishlists.participants.remove');

            // Желания в списке желаний
            Route::get('/wishlists/{wishlist}/wishes', [WishController::class, 'index'])->name('api.wishes.index');
            Route::post('/wishlists/{wishlist}/wishes', [WishController::class, 'store'])->name('api.wishes.store');
            Route::get('/wishlists/{wishlist}/wishes/{wish}', [WishController::class, 'show'])->name('api.wishes.show');
            Route::put('/wishlists/{wishlist}/wishes/{wish}', [WishController::class, 'update'])->name('api.wishes.update');
            Route::patch('/wishlists/{wishlist}/wishes/{wish}', [WishController::class, 'update']);
            Route::delete('/wishlists/{wishlist}/wishes/{wish}', [WishController::class, 'destroy'])->name('api.wishes.destroy');

            // Списки желаний и желания друзей/публичные (аггрегированные)
            Route::post('/wishes', [WishController::class, 'storeStandalone'])->name('api.wishes.store_standalone');
            Route::get('/wishes/friends', [WishController::class, 'friends'])->name('api.wishes.friends');
            Route::get('/wishes/public', [WishController::class, 'public'])->name('api.wishes.public');

            // Участники конкретного желания
            Route::get('/wishlists/{wishlist}/wishes/{wish}/participants', [WishController::class, 'participants'])->name('api.wishes.participants.index');
            Route::post('/wishlists/{wishlist}/wishes/{wish}/participants', [WishController::class, 'addParticipant'])->name('api.wishes.participants.add');
            Route::delete('/wishlists/{wishlist}/wishes/{wish}/participants/{user}', [WishController::class, 'removeParticipant'])->name('api.wishes.participants.remove');
        });
    });
