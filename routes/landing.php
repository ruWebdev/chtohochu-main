<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Landing\HomeController;

Route::domain(env('APP_DOMAIN_LANDING'))
    ->middleware(['web', 'landing'])
    ->group(function () {
        Route::get('/', HomeController::class)->name('landing.home');
    });
