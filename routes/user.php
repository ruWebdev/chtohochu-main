<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\User\DashboardController;

Route::domain(env('APP_DOMAIN_USER'))
    ->middleware(['web', 'user', 'auth'])
    ->group(function () {
        Route::get('/', DashboardController::class)->name('user.dashboard');
    });
