<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Support\Facades\DB;
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
        $vkDomain = $vkProfile['domain'] ?? null;

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

        $user = DB::transaction(function () use ($user, $providerId, $email, $name, $vkDomain) {
            if (! $user) {
                $emailForCreate = $email;

                if (! $emailForCreate) {
                    $emailForCreate = 'vk_' . $providerId . '@vk.local';
                }

                $username = $this->generateUniqueUsername($this->normalizeUsernameBase($vkDomain ?: $emailForCreate));

                return User::query()->create([
                    'name' => $name,
                    'username' => $username,
                    'email' => $emailForCreate,
                    'password' => bcrypt(Str::random(32)),
                    'vk_id' => (string) $providerId,
                ]);
            }

            $user->forceFill(array_filter([
                'name' => $name ?: null,
                'email' => $email ?: null,
                'vk_id' => $user->vk_id ?: (string) $providerId,
            ]))->save();

            if (! $user->username) {
                $username = $this->generateUniqueUsername($this->normalizeUsernameBase($vkDomain ?: ($email ?: 'vk_' . $providerId)));
                $user->forceFill(['username' => $username])->save();
            }

            return $user;
        });

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
        $name = $this->resolveYandexName($socialUser);
        $yandexLogin = $socialUser->getNickname() ?: ($socialUser->user['login'] ?? null);

        if (! $providerId) {
            throw ValidationException::withMessages([
                'access_token' => [trans('auth.social_no_id', ['provider' => 'Яндекс'])],
            ]);
        }

        $user = User::query()
            ->where('yandex_id', $providerId)
            ->when($email, fn($q) => $q->orWhere('email', $email))
            ->first();

        $user = DB::transaction(function () use ($user, $providerId, $email, $name, $yandexLogin) {
            if (! $user) {
                $emailForCreate = $email;

                if (! $emailForCreate) {
                    $emailForCreate = 'yandex_' . $providerId . '@yandex.local';
                }

                $usernameBase = $this->normalizeUsernameBase($yandexLogin ?: $emailForCreate);
                $username = $this->generateUniqueUsername($usernameBase);

                return User::query()->create([
                    'name' => $name,
                    'username' => $username,
                    'email' => $emailForCreate,
                    'password' => bcrypt(Str::random(32)),
                    'yandex_id' => (string) $providerId,
                ]);
            }

            $user->forceFill(array_filter([
                'name' => $name ?: null,
                'email' => $email ?: null,
                'yandex_id' => $user->yandex_id ?: (string) $providerId,
            ]))->save();

            if (! $user->username) {
                $usernameBase = $this->normalizeUsernameBase($yandexLogin ?: ($email ?: 'yandex_' . $providerId));
                $username = $this->generateUniqueUsername($usernameBase);
                $user->forceFill(['username' => $username])->save();
            }

            return $user;
        });

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

        $body = $response->json();

        Log::info('VK users.get response', [
            'status' => $response->status(),
            'body' => $body,
        ]);

        if (! $response->ok()) {
            return null;
        }

        if (isset($body['error'])) {
            // VK вернул ошибку авторизации или запроса
            return null;
        }

        if (! isset($body['response'][0])) {
            return null;
        }

        $user = $body['response'][0];

        return [
            'id' => $user['id'],
            'first_name' => $user['first_name'] ?? null,
            'last_name' => $user['last_name'] ?? null,
            'domain' => $user['domain'] ?? null,
        ];
    }

    protected function resolveYandexName($socialUser): string
    {
        $name = trim((string) $socialUser->getName());

        if (! $name && isset($socialUser->user['real_name'])) {
            $name = trim((string) $socialUser->user['real_name']);
        }

        if (! $name && isset($socialUser->user['display_name'])) {
            $name = trim((string) $socialUser->user['display_name']);
        }

        if (! $name && isset($socialUser->user['first_name'])) {
            $name = trim((string) $socialUser->user['first_name'] . ' ' . (string) ($socialUser->user['last_name'] ?? ''));
        }

        if (! $name) {
            $email = $socialUser->getEmail();
            if ($email && str_contains($email, '@')) {
                $name = explode('@', $email)[0];
            }
        }

        return $name ?: 'Пользователь';
    }

    protected function normalizeUsernameBase(?string $value): string
    {
        $raw = trim((string) ($value ?? ''));

        if (! $raw) {
            $raw = 'user';
        }

        if (str_contains($raw, '@')) {
            $raw = explode('@', $raw)[0];
        }

        $base = Str::slug($raw, '_');
        $base = strtolower(preg_replace('/[^a-z0-9_]+/', '', $base) ?? '');
        $base = trim($base, '_');

        if (! $base) {
            $base = 'user';
        }

        if (strlen($base) < 6) {
            $base = $base . '_' . Str::lower(Str::random(6));
        }

        return substr($base, 0, 20);
    }

    protected function generateUniqueUsername(string $base): string
    {
        $base = substr($base, 0, 20);

        $candidate = $base;
        $suffix = 1;

        while (User::query()->where('username', $candidate)->exists()) {
            $suffix++;
            $suffixStr = '_' . $suffix;
            $maxBaseLength = 20 - strlen($suffixStr);
            $candidate = substr($base, 0, max(1, $maxBaseLength)) . $suffixStr;
        }

        return $candidate;
    }
}
