<?php

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__ . '/../routes/web.php',
        api: __DIR__ . '/../routes/api.php',
        commands: __DIR__ . '/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->web(append: [
            \App\Http\Middleware\HandleInertiaRequests::class,
            \Illuminate\Http\Middleware\AddLinkHeadersForPreloadedAssets::class,
        ]);

        $middleware->alias([
            'landing' => \App\Http\Middleware\Segments\LandingSegment::class,
            'user' => \App\Http\Middleware\Segments\UserSegment::class,
            'admin' => \App\Http\Middleware\Segments\AdminSegment::class,
            'app' => \App\Http\Middleware\Segments\AppSegment::class,
            'api.segment' => \App\Http\Middleware\Segments\ApiSegment::class,
        ]);

        //
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        //
    })->create();
