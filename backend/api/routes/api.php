<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\SocialAuthController;

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

        Route::middleware('auth:sanctum')->group(function () {
            Route::get('/auth/me', [AuthController::class, 'me'])->name('api.auth.me');
            Route::post('/auth/logout', [AuthController::class, 'logout'])->name('api.auth.logout');
            Route::post('/auth/logout-all', [AuthController::class, 'logoutAll'])->name('api.auth.logout_all');
        });
    });
