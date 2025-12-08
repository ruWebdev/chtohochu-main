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
    });
