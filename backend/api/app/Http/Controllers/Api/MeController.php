<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\UpdateProfileRequest;
use App\Http\Resources\UserResource;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MeController extends Controller
{
    /**
     * Текущий пользователь + meta.has_wishes (вычисляется,
     * колонкой не хранится).
     */
    public function show(Request $request): JsonResponse
    {
        $user = $request->user();

        return (new UserResource($user))
            ->additional(['meta' => ['has_wishes' => $user->wishes()->exists()]])
            ->toResponse($request);
    }

    /**
     * Обновление профиля: name/username/avatar_url.
     * Все поля optional; null очищает nullable-поле.
     * Email и password через этот endpoint не меняются.
     */
    public function update(UpdateProfileRequest $request): JsonResponse
    {
        $user = $request->user();
        $user->fill($request->validated());
        $user->save();

        return (new UserResource($user))
            ->additional(['meta' => ['has_wishes' => $user->wishes()->exists()]])
            ->toResponse($request);
    }
}
