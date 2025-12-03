<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Profile\UpdateAvatarRequest;
use App\Services\UserStatisticsService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class ProfileAvatarController extends Controller
{
    public function store(UpdateAvatarRequest $request, UserStatisticsService $statisticsService)
    {
        $user = $request->user();

        $previousPath = $user->getRawOriginal('avatar');

        if ($previousPath) {
            Storage::disk('public')->delete($previousPath);
        }

        $file = $request->file('avatar');
        $path = $file->store('avatars', 'public');

        $user->avatar = $path;
        $user->save();

        $statistics = $statisticsService->getStatisticsForUser($user);

        return response()->json([
            'user' => array_merge($user->toArray(), [
                'statistics' => $statistics,
            ]),
            'statistics' => $statistics,
        ]);
    }

    public function destroy(Request $request, UserStatisticsService $statisticsService)
    {
        $user = $request->user();

        $previousPath = $user->getRawOriginal('avatar');

        if ($previousPath) {
            Storage::disk('public')->delete($previousPath);
        }

        $user->avatar = null;
        $user->save();

        $statistics = $statisticsService->getStatisticsForUser($user);

        return response()->json([
            'user' => array_merge($user->toArray(), [
                'statistics' => $statistics,
            ]),
            'statistics' => $statistics,
        ]);
    }
}
