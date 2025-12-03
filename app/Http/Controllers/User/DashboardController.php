<?php

namespace App\Http\Controllers\User;

use Inertia\Inertia;
use Inertia\Response;

class DashboardController
{
    public function __invoke(): Response
    {
        return Inertia::render('User/Dashboard', [
            'title' => __('user.title'),
            'description' => __('user.description'),
        ]);
    }
}
