<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\UserResource;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use Laravel\Socialite\Facades\Socialite;

class SocialAuthController extends Controller
{
    private const PROVIDER_COLUMN = [
        'vk' => 'vk_id',
        'yandex' => 'yandex_id',
    ];

    private const PROVIDER_LABEL = [
        'vk' => 'VK',
        'yandex' => 'Яндекс',
    ];

    /**
     * Вход через VK ID — authorization code flow + PKCE.
     *
     * Клиент присылает код подтверждения из redirect-URL и
     * code_verifier; backend обменивает код на access_token
     * серверным запросом к id.vk.ru (токен из implicit-флоу
     * IP-bound и непригоден для серверных вызовов).
     */
    public function vk(Request $request)
    {
        $data = $request->validate([
            'code' => ['required', 'string'],
            'device_id' => ['required', 'string'],
            'code_verifier' => ['required', 'string', 'min:43', 'max:128'],
            'state' => ['nullable', 'string', 'max:255'],
        ]);

        $profile = $this->fetchVkProfile($data);

        if (! $profile) {
            throw ValidationException::withMessages([
                'code' => [trans('auth.social_failed', ['provider' => 'VK'])],
            ]);
        }

        return $this->loginVia('vk', $profile, $request);
    }

    /**
     * Вход через Яндекс по access_token.
     */
    public function yandex(Request $request)
    {
        $data = $request->validate([
            'access_token' => ['required', 'string'],
        ]);

        $profile = $this->fetchYandexProfile($data['access_token']);

        if (! $profile) {
            throw ValidationException::withMessages([
                'access_token' => [trans('auth.social_failed', ['provider' => 'Яндекс'])],
            ]);
        }

        return $this->loginVia('yandex', $profile, $request);
    }

    /**
     * Подтверждённая привязка VK к текущему аккаунту (auth:sanctum).
     */
    public function linkVk(Request $request)
    {
        return $this->link('vk', $request);
    }

    /**
     * Подтверждённая привязка Яндекса к текущему аккаунту (auth:sanctum).
     */
    public function linkYandex(Request $request)
    {
        return $this->link('yandex', $request);
    }

    /**
     * Общий сценарий входа через провайдера:
     * найти по provider_id → создать → Sanctum-токен.
     *
     * Автоматической привязки по email НЕТ: совпадение адреса с
     * существующим аккаунтом завершается 409 — привязка выполняется
     * только подтверждённо из авторизованной сессии через
     * POST /auth/{provider}/link. Иначе чужой провайдер-аккаунт
     * с тем же email открыл бы доступ к аккаунту пользователя.
     */
    private function loginVia(string $provider, array $profile, Request $request)
    {
        $label = self::PROVIDER_LABEL[$provider];
        $column = self::PROVIDER_COLUMN[$provider];
        $providerId = $profile['id'] ?? null;

        if (! $providerId) {
            throw ValidationException::withMessages([
                'access_token' => [trans('auth.social_no_id', ['provider' => $label])],
            ]);
        }
        $providerId = (string) $providerId;
        $email = $profile['email'] ?? null;

        $user = User::query()->where($column, $providerId)->first();

        if (! $user) {
            if ($email && User::query()->where('email', $email)->exists()) {
                return response()->json([
                    'message' => trans('auth.social_link_required', ['provider' => $label]),
                    'code' => 'oauth_link_required',
                ], 409);
            }

            $user = DB::transaction(
                fn () => $this->createSocialUser($provider, $profile, $email),
            );
        } else {
            $this->backfillProfile($user, $profile);
        }

        $token = $user->createToken($provider.'_login')->plainTextToken;

        return response()->json([
            'data' => [
                'token' => $token,
                'user' => (new UserResource($user))->toArray($request),
            ],
        ]);
    }

    /**
     * Привязка провайдера к авторизованному пользователю.
     * Идемпотентна: повторная привязка того же provider-аккаунта —
     * успешный no-op. Перепривязка на другой provider-аккаунт и
     * захват provider-аккаунта чужого пользователя отклоняются 409.
     */
    private function link(string $provider, Request $request)
    {
        $data = $provider === 'vk'
            ? $request->validate([
                'code' => ['required', 'string'],
                'device_id' => ['required', 'string'],
                'code_verifier' => ['required', 'string', 'min:43', 'max:128'],
                'state' => ['nullable', 'string', 'max:255'],
            ])
            : $request->validate([
                'access_token' => ['required', 'string'],
            ]);

        $label = self::PROVIDER_LABEL[$provider];

        $profile = $provider === 'vk'
            ? $this->fetchVkProfile($data)
            : $this->fetchYandexProfile($data['access_token']);

        if (! $profile) {
            throw ValidationException::withMessages([
                $provider === 'vk' ? 'code' : 'access_token' => [
                    trans('auth.social_failed', ['provider' => $label]),
                ],
            ]);
        }

        $providerId = $profile['id'] ?? null;

        if (! $providerId) {
            throw ValidationException::withMessages([
                'access_token' => [trans('auth.social_no_id', ['provider' => $label])],
            ]);
        }
        $providerId = (string) $providerId;

        $column = self::PROVIDER_COLUMN[$provider];
        $user = $request->user();

        $taken = User::query()
            ->where($column, $providerId)
            ->where('id', '!=', $user->id)
            ->exists();

        if ($taken) {
            return response()->json([
                'message' => trans('auth.social_provider_taken', ['provider' => $label]),
                'code' => 'oauth_provider_taken',
            ], 409);
        }

        if ($user->{$column} && $user->{$column} !== $providerId) {
            return response()->json([
                'message' => trans('auth.social_already_linked', ['provider' => $label]),
                'code' => 'oauth_already_linked',
            ], 409);
        }

        if ($user->{$column} !== $providerId) {
            $user->forceFill([$column => $providerId])->save();
        }

        $this->backfillProfile($user->refresh(), $profile);

        return response()->json([
            'data' => [
                'user' => (new UserResource($user))->toArray($request),
            ],
        ]);
    }

    /**
     * Создание аккаунта по данным провайдера. Без реального email —
     * синтетический `{provider}_{id}@{provider}.local`, уникальный
     * по построению и не доставляемый по определению.
     */
    private function createSocialUser(string $provider, array $profile, ?string $email): User
    {
        $column = self::PROVIDER_COLUMN[$provider];
        $providerId = (string) $profile['id'];
        $emailForCreate = $email ?: "{$provider}_{$providerId}@{$provider}.local";
        $usernameBase = $profile['login'] ?? $emailForCreate;

        return User::query()->create([
            'name' => $profile['name'] ?: self::PROVIDER_LABEL[$provider],
            'username' => $this->generateUniqueUsername(
                $this->normalizeUsernameBase($usernameBase),
            ),
            'email' => $emailForCreate,
            'password' => bcrypt(Str::random(32)),
            'avatar_url' => $profile['avatar'] ?? null,
            $column => $providerId,
        ]);
    }

    /**
     * Дозаполнение пустых полей профиля у существующего
     * пользователя. Провайдер никогда не перезаписывает
     * отредактированный профиль и не меняет email аккаунта.
     */
    private function backfillProfile(User $user, array $profile): void
    {
        $fill = [];

        if (! $user->name && ! empty($profile['name'])) {
            $fill['name'] = $profile['name'];
        }
        if (! $user->avatar_url && ! empty($profile['avatar'])) {
            $fill['avatar_url'] = $profile['avatar'];
        }
        if (! $user->username) {
            $fill['username'] = $this->generateUniqueUsername(
                $this->normalizeUsernameBase($profile['login'] ?? $user->email),
            );
        }

        if ($fill) {
            $user->forceFill($fill)->save();
        }
    }

    /**
     * Профиль VK ID по коду подтверждения (authorization code + PKCE).
     *
     * 1. `POST id.vk.ru/oauth2/auth` — обмен code на access_token,
     *    привязанный к серверу (implicit-токены VK IP-bound к
     *    устройству и не работают из backend).
     * 2. `POST id.vk.ru/oauth2/user_info` — профиль пользователя
     *    (email приходит при scope=email).
     *
     * `null` — обмен или user_info отклонены провайдером (→ 422).
     * Токены и коды провайдера в логи не пишутся.
     */
    protected function fetchVkProfile(array $data): ?array
    {
        $vkConfig = config('services.vk');
        $redirectUri = config('services.vkontakte.redirect');

        try {
            $tokenResponse = Http::asForm()->post('https://id.vk.ru/oauth2/auth', [
                'grant_type' => 'authorization_code',
                'code' => $data['code'],
                'code_verifier' => $data['code_verifier'],
                'client_id' => $vkConfig['client_id'],
                'device_id' => $data['device_id'],
                'redirect_uri' => $redirectUri,
                'state' => $data['state'] ?? '',
            ]);
        } catch (\Throwable $e) {
            Log::error('VK token exchange failed: '.$e->getMessage());

            return null;
        }

        $tokenBody = $tokenResponse->json();
        $accessToken = $tokenBody['access_token'] ?? null;

        if (! $tokenResponse->ok() || ! $accessToken) {
            Log::error('VK token exchange rejected', [
                'status' => $tokenResponse->status(),
                'error' => $tokenBody['error'] ?? null,
                'error_description' => $tokenBody['error_description'] ?? null,
            ]);

            return null;
        }

        try {
            $infoResponse = Http::asForm()->post('https://id.vk.ru/oauth2/user_info', [
                'client_id' => $vkConfig['client_id'],
                'access_token' => $accessToken,
            ]);
        } catch (\Throwable $e) {
            Log::error('VK user_info failed: '.$e->getMessage());

            return null;
        }

        $user = $infoResponse->json('user');

        if (! $infoResponse->ok() || ! is_array($user) || empty($user['user_id'])) {
            Log::error('VK user_info rejected', [
                'status' => $infoResponse->status(),
                'error' => $infoResponse->json('error') ?? null,
            ]);

            return null;
        }

        $name = trim(($user['first_name'] ?? '').' '.($user['last_name'] ?? ''));

        return [
            'id' => $user['user_id'],
            'name' => $name ?: null,
            'login' => null,
            'avatar' => $user['avatar'] ?? null,
            'email' => isset($user['email'])
                ? mb_strtolower((string) $user['email'])
                : null,
        ];
    }

    /**
     * Профиль Яндекса через Socialite userFromToken.
     * `null` — провайдер отклонил токен (→ 422 social_failed).
     */
    protected function fetchYandexProfile(string $accessToken): ?array
    {
        try {
            $socialUser = Socialite::driver('yandex')->userFromToken($accessToken);
        } catch (\Throwable $e) {
            Log::error('Yandex Auth Failed: '.$e->getMessage());

            return null;
        }

        return [
            'id' => $socialUser->getId(),
            'email' => $socialUser->getEmail(),
            'name' => $this->resolveYandexName($socialUser),
            'login' => $socialUser->getNickname() ?: ($socialUser->user['login'] ?? null),
            'avatar' => $socialUser->getAvatar(),
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
            $name = trim((string) $socialUser->user['first_name'].' '.(string) ($socialUser->user['last_name'] ?? ''));
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
            $base = $base.'_'.Str::lower(Str::random(6));
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
            $suffixStr = '_'.$suffix;
            $maxBaseLength = 20 - strlen($suffixStr);
            $candidate = substr($base, 0, max(1, $maxBaseLength)).$suffixStr;
        }

        return $candidate;
    }
}
