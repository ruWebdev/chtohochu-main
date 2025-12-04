<?php

namespace App\Http\Controllers\Api;

use App\Actions\Auth\RegisterUserAction;
use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\LoginRequest;
use App\Http\Requests\Auth\RegisterRequest;
use App\Services\UserStatisticsService;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class AuthController extends Controller
{
    public function register(RegisterRequest $request, RegisterUserAction $action)
    {
        $user = $action->execute($request->validated());

        $token = $user->createToken('auth')->plainTextToken;

        return response()->json([
            'user' => $user,
            'token' => $token,
        ], 201);
    }

    public function login(LoginRequest $request)
    {
        $request->ensureIsNotRateLimited();

        if (! Auth::attempt($request->only('email', 'password'))) {
            return response()->json([
                'message' => trans('auth.failed'),
            ], 422);
        }

        $user = $request->user();
        $token = $user->createToken('auth')->plainTextToken;

        return response()->json([
            'user' => $user,
            'token' => $token,
        ]);
    }

    public function checkUsername(Request $request)
    {
        $validated = $request->validate([
            'username' => ['required', 'string', 'min:6', 'max:20', 'regex:/^[a-z0-9_]+$/'],
        ]);

        $username = strtolower($validated['username']);

        $exists = User::query()
            ->where('username', $username)
            ->exists();

        return response()->json([
            'available' => ! $exists,
        ]);
    }

    public function me(Request $request, UserStatisticsService $statisticsService)
    {
        $user = $request->user();

        $statistics = $statisticsService->getStatisticsForUser($user);

        return response()->json([
            'user' => array_merge($user->toArray(), [
                'statistics' => $statistics,
            ]),
            'statistics' => $statistics,
        ]);
    }

    public function logout(Request $request)
    {
        $request->user()?->currentAccessToken()?->delete();
        return response()->json(['message' => __('auth.logged_out')]);
    }

    public function logoutAll(Request $request)
    {
        $request->user()?->tokens()->delete();
        return response()->json(['message' => __('auth.logged_out_all')]);
    }
}
