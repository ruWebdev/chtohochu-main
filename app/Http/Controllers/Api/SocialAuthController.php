<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\ValidationException;
use Laravel\Socialite\Facades\Socialite;

class SocialAuthController extends Controller
{
    /**
     * Вход через VK по access_token.
     */
    public function vk(Request $request)
    {
        $data = $request->validate([
            'access_token' => ['required', 'string'],
        ]);

        $accessToken = $data['access_token'];

        $vkProfile = $this->fetchVkProfile($accessToken);

        if (! $vkProfile) {
            throw ValidationException::withMessages([
                'access_token' => [trans('auth.social_failed', ['provider' => 'VK'])],
            ]);
        }

        $providerId = $vkProfile['id'] ?? null;
        $email = $vkProfile['email'] ?? null;
        $name = trim(($vkProfile['first_name'] ?? '') . ' ' . ($vkProfile['last_name'] ?? ''));

        if (! $providerId) {
            throw ValidationException::withMessages([
                'access_token' => [trans('auth.social_no_id', ['provider' => 'VK'])],
            ]);
        }

        if (! $name) {
            $name = 'Пользователь VK';
        }

        $user = User::query()
            ->where('vk_id', $providerId)
            ->when($email, fn($q) => $q->orWhere('email', $email))
            ->first();

        if (! $user) {
            $user = User::query()->create([
                'name' => $name,
                'email' => $email,
                'password' => bcrypt(Str::random(32)),
                'vk_id' => (string) $providerId,
            ]);
        } else {
            $user->forceFill(array_filter([
                'name' => $name ?: null,
                'email' => $email ?: null,
                'vk_id' => $user->vk_id ?: (string) $providerId,
            ]))->save();
        }

        $token = $user->createToken('vk_login')->plainTextToken;

        return response()->json([
            'user' => $user,
            'token' => $token,
        ]);
    }

    /**
     * Вход через Яндекс по access_token.
     */
    public function yandex(Request $request)
    {
        $data = $request->validate([
            'access_token' => ['required', 'string'],
        ]);

        $accessToken = $data['access_token'];

        try {
            $socialUser = Socialite::driver('yandex')->userFromToken($accessToken);
        } catch (\Throwable $e) {
            Log::error('Yandex Auth Failed: ' . $e->getMessage());
            throw ValidationException::withMessages([
                'access_token' => [trans('auth.social_failed', ['provider' => 'Яндекс'])],
            ]);
        }

        $providerId = $socialUser->getId();
        $email = $socialUser->getEmail();
        $name = $socialUser->getName();
        if (empty($name) && isset($socialUser->user['real_name'])) {
            $name = $socialUser->user['real_name'];
        }
        if (empty($name) && isset($socialUser->user['first_name'])) {
            $name = $socialUser->user['first_name'] . (isset($socialUser->user['last_name']) ? ' ' . $socialUser->user['last_name'] : '');
        }
        if (empty($name)) {
            $name = 'Пользователь Яндекс';
        }

        if (! $providerId) {
            throw ValidationException::withMessages([
                'access_token' => [trans('auth.social_no_id', ['provider' => 'Яндекс'])],
            ]);
        }

        $user = User::query()
            ->where('yandex_id', $providerId)
            ->when($email, fn($q) => $q->orWhere('email', $email))
            ->first();

        if (! $user) {
            $user = User::query()->create([
                'name' => $name,
                'email' => $email,
                'password' => bcrypt(Str::random(32)),
                'yandex_id' => (string) $providerId,
            ]);
        } else {
            $user->forceFill(array_filter([
                'name' => $name ?: null,
                'email' => $email ?: null,
                'yandex_id' => $user->yandex_id ?: (string) $providerId,
            ]))->save();
        }

        $token = $user->createToken('yandex_login')->plainTextToken;

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
        ];
    }
}
