<?php

namespace App\Http\Middleware\Segments;

use Closure;
use Illuminate\Http\Request;

class AppSegment
{
    public function handle(Request $request, Closure $next)
    {
        return $next($request);
    }
}
