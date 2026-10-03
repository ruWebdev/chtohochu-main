<?php

namespace Tests;

use Illuminate\Foundation\Testing\TestCase as BaseTestCase;

abstract class TestCase extends BaseTestCase
{
    /**
     * API routes привязаны к домену api.chtohochu.test
     * (Route::domain), поэтому в тестах ходим на полный URL.
     */
    protected function api(string $path): string
    {
        return 'http://api.chtohochu.test/api/v1'.$path;
    }
}
