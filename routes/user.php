<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\User\DashboardController;
use App\Http\Controllers\ProfileController;

Route::domain(env('APP_DOMAIN_USER'))
    ->middleware(['web', 'user'])
    ->group(function () {
        // Защищённые маршруты
        Route::middleware(['auth', 'verified'])->group(function () {
            Route::get('/', DashboardController::class)->name('user.dashboard');
            Route::get('/dashboard', DashboardController::class)->name('dashboard');
        });

        // Маршруты профиля
        Route::middleware('auth')->group(function () {
            Route::get('/profile', [ProfileController::class, 'edit'])->name('profile.edit');
            Route::patch('/profile', [ProfileController::class, 'update'])->name('profile.update');
            Route::delete('/profile', [ProfileController::class, 'destroy'])->name('profile.destroy');
        });
    });
