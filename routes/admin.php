<?php

use Illuminate\Support\Facades\Route;
use Inertia\Inertia;

Route::domain(env('APP_DOMAIN_ADMIN'))
    ->middleware(['web', 'admin', 'auth'])
    ->group(function () {
        Route::get('/', function () {
            return Inertia::render('Admin/Dashboard');
        })->name('admin.dashboard');
    });
