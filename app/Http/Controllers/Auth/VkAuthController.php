<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class VkAuthController extends Controller
{
    public function login(Request $request)
    {
        $data = $request->validate([
            'access_token' => ['required', 'string'],
        ]);

        $accessToken = $data['access_token'];

        // 1. Валидируем токен и получаем профиль VK
        $vkProfile = $this->fetchVkProfile($accessToken);

        if (! $vkProfile) {
            throw ValidationException::withMessages([
                'access_token' => ['Не удалось подтвердить токен VK.'],
            ]);
        }

        // Минимальные данные
        $vkId = $vkProfile['id'] ?? null;
        $email = $vkProfile['email'] ?? null;
        $name = trim(($vkProfile['first_name'] ?? '') . ' ' . ($vkProfile['last_name'] ?? ''));

        if (! $vkId) {
            throw ValidationException::withMessages([
                'access_token' => ['VK не вернул идентификатор пользователя.'],
            ]);
        }

        // 2. Ищем/создаём пользователя
        $user = User::query()
            ->where('vk_id', $vkId)
            ->when($email, fn($q) => $q->orWhere('email', $email))
            ->first();

        if (! $user) {
            $user = User::query()->create([
                'name' => $name ?: 'Пользователь VK',
                'email' => $email,
                'password' => bcrypt(Str::random(32)),
                'vk_id' => (string) $vkId,
            ]);
        } else {
            // При необходимости можно обновлять имя/email
            $user->forceFill(array_filter([
                'name' => $name ?: null,
                'email' => $email ?: null,
            ]))->save();
        }

        // 3. Создаем Sanctum‑токен
        $token = $user->createToken('vk_login')->plainTextToken;

        return response()->json([
            'user' => $user,
            'token' => $token,
        ]);
    }

    /**
     * Запрашивает профиль пользователя у VK по access_token.
     */
    protected function fetchVkProfile(string $accessToken): ?array
    {
        $vkConfig = config('services.vk');

        $response = Http::withHeaders([
            // Не логируем access_token, только минимальные заголовки
            'User-Agent' => 'Mozilla/5.0 (compatible; chtohochu-app/1.0)',
        ])->get('https://api.vk.com/method/users.get', [
            'access_token' => $accessToken,
            'v' => $vkConfig['version'] ?? '5.199',
            'fields' => 'id,first_name,last_name,photo_200,domain',
        ]);

        if (! $response->ok()) {
            return null;
        }

        $body = $response->json();

        if (! isset($body['response'][0])) {
            return null;
        }

        $user = $body['response'][0];

        return [
            'id' => $user['id'],
            'first_name' => $user['first_name'] ?? null,
            'last_name' => $user['last_name'] ?? null,
            // 'email' => ..., // если доступен в вашем потоке авторизации VK ID
        ];
    }
}
