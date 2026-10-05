<?php

namespace App\Providers;

use App\Services\Media\MediaStorageGateway;
use App\Services\Media\S3MediaStorageGateway;
use Illuminate\Support\Facades\Vite;
use Illuminate\Support\ServiceProvider;
use SocialiteProviders\Manager\SocialiteWasCalled;
use SocialiteProviders\VKontakte\Provider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        // Object storage — за интерфейсом MediaStorageGateway, чтобы
        // upload lifecycle тестировался без реального S3.
        $this->app->bind(
            MediaStorageGateway::class,
            S3MediaStorageGateway::class,
        );
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        Vite::prefetch(concurrency: 3);

        // Регистрация OAuth-провайдеров для Socialite
        $this->app['events']->listen(function (SocialiteWasCalled $event) {
            $event->extendSocialite('vkontakte', Provider::class);
        });

        $this->app['events']->listen(function (SocialiteWasCalled $event) {
            $event->extendSocialite('yandex', \SocialiteProviders\Yandex\Provider::class);
        });
    }
}
