<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Sharing\ResolveController;
use App\Http\Controllers\Sharing\WishlistPreviewController;
use App\Http\Controllers\Sharing\WishPreviewController;
use App\Http\Controllers\Sharing\ShoppingListPreviewController;
use App\Http\Controllers\Sharing\UserPreviewController;

Route::domain(env('APP_DOMAIN_APP'))
    ->middleware(['web', 'app'])
    ->group(function () {
        Route::get('/share/resolve', ResolveController::class)->name('sharing.resolve');

        Route::get('/preview/wishlist/{wishlist}', WishlistPreviewController::class)
            ->name('sharing.preview.wishlist');

        Route::get('/preview/wish/{wish}', WishPreviewController::class)
            ->name('sharing.preview.wish');

        Route::get('/preview/shopping-list/{shoppingList}', ShoppingListPreviewController::class)
            ->name('sharing.preview.shopping_list');

        Route::get('/preview/user/{username}', UserPreviewController::class)
            ->name('sharing.preview.user');

        // Универсальные ссылки Smart Links
        Route::get('/app', function () {
            return redirect()->route('sharing.resolve', ['path' => 'app']);
        })->name('sharing.universal.app');

        Route::get('/wishlist/{id}', function (string $id) {
            return redirect()->route('sharing.preview.wishlist', ['wishlist' => $id]);
        })->name('sharing.universal.wishlist');

        Route::get('/wish/{id}', function (string $id) {
            return redirect()->route('sharing.preview.wish', ['wish' => $id]);
        })->name('sharing.universal.wish');

        Route::get('/shopping-list/{id}', function (string $id) {
            return redirect()->route('sharing.preview.shopping_list', ['shoppingList' => $id]);
        })->name('sharing.universal.shopping_list');

        Route::get('/user/{username}', function (string $username) {
            return redirect()->route('sharing.preview.user', ['username' => $username]);
        })->name('sharing.universal.user');
    });
