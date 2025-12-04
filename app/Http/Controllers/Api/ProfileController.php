<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Profile\UpdateProfileApiRequest;
use App\Services\UserStatisticsService;
use Illuminate\Support\Facades\Hash;

class ProfileController extends Controller
{
    public function update(UpdateProfileApiRequest $request, UserStatisticsService $statisticsService)
    {
        $user = $request->user();

        $data = $request->validated();

        if (isset($data['username'])) {
            $data['username'] = strtolower($data['username']);
        }

        if (isset($data['password'])) {
            $data['password'] = Hash::make($data['password']);
        }

        $user->fill($data);
        $user->save();

        $user->refresh();

        $statistics = $statisticsService->getStatisticsForUser($user);

        return response()->json([
            'user' => array_merge($user->toArray(), [
                'statistics' => $statistics,
            ]),
        ]);
    }
}
