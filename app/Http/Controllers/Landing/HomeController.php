<?php

namespace App\Http\Controllers\Landing;

use Inertia\Inertia;
use Inertia\Response;

class HomeController
{
    public function __invoke(): Response
    {
        return Inertia::render('Landing/Home', [
            'title' => __('landing.title'),
            'description' => __('landing.subtitle'),
            'soon' => __('landing.soon'),
        ]);
    }
}
