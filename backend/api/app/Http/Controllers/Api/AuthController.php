<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\LoginRequest;
use App\Http\Requests\Api\RegisterRequest;
use App\Http\Resources\UserResource;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;

class AuthController extends Controller
{
    /**
     * Регистрация: email/password (+optional name/username).
     * Создаёт Sanctum token, отдаёт user + token. 201.
     */
    public function register(RegisterRequest $request): JsonResponse
    {
        $user = DB::transaction(function () use ($request) {
            $user = new User($request->only(['name', 'username', 'email']));
            $user->password = $request->string('password')->toString();
            $user->save();

            return $user;
        });

        $token = $user->createToken('api')->plainTextToken;

        return response()->json([
            'data' => [
                'token' => $token,
                'user' => (new UserResource($user))->toArray($request),
            ],
        ], 201);
    }

    /**
     * Вход: проверка credentials, выдача Sanctum token. 200.
     * Неверные credentials — 401 без раскрытия, существует ли email.
     */
    public function login(LoginRequest $request): JsonResponse
    {
        $user = User::where('email', $request->string('email')->toString())->first();

        if (! $user || ! Hash::check($request->string('password')->toString(), (string) $user->password)) {
            return response()->json(['message' => 'Invalid credentials.'], 401);
        }

        $token = $user->createToken('api')->plainTextToken;

        return response()->json([
            'data' => [
                'token' => $token,
                'user' => (new UserResource($user))->toArray($request),
            ],
        ]);
    }

    /**
     * Проверка доступности username (регистрация на клиенте).
     */
    public function checkUsername(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'username' => [
                'required',
                'string',
                'regex:/^[a-z0-9_.]{3,20}$/',
                Rule::unique('users', 'username'),
            ],
        ]);

        return response()->json([
            'data' => ['available' => true, 'username' => $validated['username']],
        ]);
    }

    /**
     * Отзыв текущего Sanctum token (не всех). 204.
     */
    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()?->delete();

        return response()->json(null, 204);
    }

    /**
     * Отзыв всех Sanctum tokens пользователя. 204.
     */
    public function logoutAll(Request $request): JsonResponse
    {
        $request->user()->tokens()->delete();

        return response()->json(null, 204);
    }
}
