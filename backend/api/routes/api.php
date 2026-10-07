<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\FriendController;
use App\Http\Controllers\Api\MeController;
use App\Http\Controllers\Api\MediaUploadController;
use App\Http\Controllers\Api\ShareController;
use App\Http\Controllers\Api\ShoppingItemController;
use App\Http\Controllers\Api\ShoppingListController;
use App\Http\Controllers\Api\SocialAuthController;
use App\Http\Controllers\Api\UserController;
use App\Http\Controllers\Api\WishController;
use App\Http\Controllers\Api\WishListController;
use Illuminate\Support\Facades\Route;

Route::domain(env('APP_DOMAIN_API'))
    ->middleware(['api'])
    ->prefix('v1')
    ->group(function () {
        // Health check
        Route::get('/health', fn () => response()->json(['status' => 'ok']));

        // Аутентификация (Sanctum)
        Route::post('/auth/register', [AuthController::class, 'register'])->name('api.auth.register');
        Route::get('/auth/username/check', [AuthController::class, 'checkUsername'])->name('api.auth.username.check');
        Route::post('/auth/login', [AuthController::class, 'login'])->name('api.auth.login');
        Route::post('/auth/vk', [SocialAuthController::class, 'vk'])
            ->middleware('throttle:10,1');
        Route::post('/auth/yandex', [SocialAuthController::class, 'yandex'])
            ->middleware('throttle:10,1');

        // Публичный share resolver — capability-токен вместо entity
        // UUID, единый 404 на любое недействительное состояние.
        Route::get('/share/{token}', [ShareController::class, 'show'])
            ->middleware('throttle:60,1')
            ->name('api.share.show');

        Route::middleware('auth:sanctum')->group(function () {
            Route::post('/auth/logout', [AuthController::class, 'logout'])->name('api.auth.logout');
            Route::post('/auth/logout-all', [AuthController::class, 'logoutAll'])->name('api.auth.logout_all');

            // Текущий пользователь
            Route::get('/me', [MeController::class, 'show'])->name('api.me.show');
            Route::patch('/me', [MeController::class, 'update'])->name('api.me.update');

            // Желания (owner-only)
            Route::get('/wishes', [WishController::class, 'index'])->name('api.wishes.index');
            Route::post('/wishes', [WishController::class, 'store'])->name('api.wishes.store');
            Route::get('/wishes/{wish}', [WishController::class, 'show'])->name('api.wishes.show');
            Route::patch('/wishes/{wish}', [WishController::class, 'update'])->name('api.wishes.update');
            Route::delete('/wishes/{wish}', [WishController::class, 'destroy'])->name('api.wishes.destroy');

            // Списки желаний (owner-only, soft delete)
            Route::get('/wish-lists', [WishListController::class, 'index'])->name('api.wish_lists.index');
            Route::post('/wish-lists', [WishListController::class, 'store'])->name('api.wish_lists.store');
            Route::get('/wish-lists/{wishList}', [WishListController::class, 'show'])->name('api.wish_lists.show');
            Route::patch('/wish-lists/{wishList}', [WishListController::class, 'update'])->name('api.wish_lists.update');
            Route::delete('/wish-lists/{wishList}', [WishListController::class, 'destroy'])->name('api.wish_lists.destroy');

            // Sharing (owner-only): создание capability-ссылки и revoke.
            Route::post('/wishes/{wish}/share', [ShareController::class, 'storeForWish'])->name('api.wishes.share');
            Route::post('/wish-lists/{wishList}/share', [ShareController::class, 'storeForWishList'])->name('api.wish_lists.share');
            Route::delete('/shares/{share}', [ShareController::class, 'destroy'])->name('api.shares.destroy');

            // Поиск пользователей
            Route::get('/users/search', [UserController::class, 'search'])->name('api.users.search');

            // Друзья (дружба симметрична — одна запись на пару)
            Route::get('/friends', [FriendController::class, 'index'])->name('api.friends.index');
            Route::post('/friends', [FriendController::class, 'store'])->name('api.friends.store');
            Route::get('/friends/{user}', [FriendController::class, 'show'])->name('api.friends.show');
            Route::get('/friends/{user}/wishes', [FriendController::class, 'wishes'])->name('api.friends.wishes');
            Route::delete('/friends/{user}', [FriendController::class, 'destroy'])->name('api.friends.destroy');

            // Списки покупок (owner-only)
            Route::get('/shopping-lists', [ShoppingListController::class, 'index'])->name('api.shopping_lists.index');
            Route::post('/shopping-lists', [ShoppingListController::class, 'store'])->name('api.shopping_lists.store');
            Route::get('/shopping-lists/{shoppingList}', [ShoppingListController::class, 'show'])->name('api.shopping_lists.show');
            Route::patch('/shopping-lists/{shoppingList}', [ShoppingListController::class, 'update'])->name('api.shopping_lists.update');
            Route::delete('/shopping-lists/{shoppingList}', [ShoppingListController::class, 'destroy'])->name('api.shopping_lists.destroy');

            // Media uploads (ADR-015): presigned PUT → complete.
            Route::post('/media/uploads', [MediaUploadController::class, 'store'])->name('api.media.uploads.store');
            Route::post('/media/uploads/{mediaUpload}/complete', [MediaUploadController::class, 'complete'])->name('api.media.uploads.complete');

            // Позиции: атомарные мутации, без whole-list sync
            Route::post('/shopping-lists/{shoppingList}/items', [ShoppingItemController::class, 'store'])->name('api.shopping_items.store');
            Route::patch('/shopping-items/{shoppingItem}', [ShoppingItemController::class, 'update'])->name('api.shopping_items.update');
            Route::delete('/shopping-items/{shoppingItem}', [ShoppingItemController::class, 'destroy'])->name('api.shopping_items.destroy');
        });
    });
