<?php

namespace App\Http\Controllers\Api;

use App\Actions\Auth\RegisterUserAction;
use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\LoginRequest;
use App\Http\Requests\Auth\RegisterRequest;
use App\Models\Wish;
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
        ]);
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

    public function me(Request $request)
    {
        $user = $request->user();

        $totalWishes = Wish::query()
            ->whereHas('wishlist', function ($query) use ($user) {
                $query->where('owner_id', $user->id);
            })
            ->count();

        $fulfilledWishes = Wish::query()
            ->whereHas('wishlist', function ($query) use ($user) {
                $query->where('owner_id', $user->id);
            })
            ->where('status', Wish::STATUS_FULFILLED)
            ->count();

        $friendsCount = $user->friends()->count();

        return response()->json([
            'user' => $user,
            'statistics' => [
                'wishes_total' => $totalWishes,
                'wishes_fulfilled' => $fulfilledWishes,
                'friends_total' => $friendsCount,
            ],
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
