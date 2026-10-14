<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Laravel\Socialite\Facades\Socialite;
use Laravel\Socialite\Two\User as SocialiteUser;
use Mockery;
use Tests\TestCase;

/**
 * OAuth-вход через VK / Яндекс и подтверждённая привязка
 * провайдеров к аккаунту (docs/20-backend/oauth.md).
 */
class SocialAuthApiTest extends TestCase
{
    use RefreshDatabase;

    /**
     * users.get отвечает успехом с заданным VK-профилем.
     */
    private function fakeVkUsersGet(array $overrides = []): void
    {
        Http::fake([
            'api.vk.com/method/users.get*' => Http::response([
                'response' => [
                    array_merge([
                        'id' => 12345,
                        'first_name' => 'Иван',
                        'last_name' => 'Петров',
                        'domain' => 'ivan_petrov',
                        'photo_200' => 'https://img.example/vk.png',
                    ], $overrides),
                ],
            ], 200),
        ]);
    }

    /**
     * Socialite::driver('yandex')->userFromToken() возвращает
     * подготовленный профиль.
     */
    private function fakeYandexUser(array $map = [], array $raw = []): void
    {
        $socialUser = new SocialiteUser;
        $socialUser->map(array_merge([
            'id' => '777',
            'nickname' => 'ivan_ya',
            'name' => 'Иван Яндексов',
            'email' => 'ivan@yandex.ru',
            'avatar' => 'https://avatars.yandex.net/get-yapic/x/islands-200',
        ], $map));
        $socialUser->user = array_merge(['login' => 'ivan_ya'], $raw);

        $provider = Mockery::mock();
        $provider->shouldReceive('userFromToken')
            ->with('ya-token')
            ->andReturn($socialUser);

        Socialite::shouldReceive('driver')
            ->with('yandex')
            ->andReturn($provider);
    }

    private function fakeYandexFailure(): void
    {
        $provider = Mockery::mock();
        $provider->shouldReceive('userFromToken')
            ->andThrow(new \RuntimeException('invalid token'));

        Socialite::shouldReceive('driver')
            ->with('yandex')
            ->andReturn($provider);
    }

    // ─── VK ───────────────────────────────────────────────

    public function test_vk_login_creates_user_with_fragment_email(): void
    {
        $this->fakeVkUsersGet();

        $response = $this->postJson($this->api('/auth/vk'), [
            'access_token' => 'vk-token',
            'email' => 'Ivan@Mail.ru',
        ])->assertOk()
            ->assertJsonStructure([
                'data' => [
                    'token',
                    'user' => ['id', 'email', 'name', 'username', 'avatar_url'],
                ],
            ])
            ->assertJsonPath('data.user.email', 'ivan@mail.ru')
            ->assertJsonPath('data.user.avatar_url', 'https://img.example/vk.png');

        // Сырой модели не отдаём: provider-ids не должны утекать
        // в API-ответ.
        $this->assertArrayNotHasKey('vk_id', $response->json('data.user'));

        $this->assertDatabaseHas('users', [
            'email' => 'ivan@mail.ru',
            'vk_id' => '12345',
        ]);
        $this->assertDatabaseCount('personal_access_tokens', 1);
    }

    public function test_vk_login_without_email_uses_synthetic_address(): void
    {
        $this->fakeVkUsersGet(['id' => 555]);

        $this->postJson($this->api('/auth/vk'), [
            'access_token' => 'vk-token',
        ])->assertOk()
            ->assertJsonPath('data.user.email', 'vk_555@vk.local');

        $this->assertDatabaseHas('users', [
            'email' => 'vk_555@vk.local',
            'vk_id' => '555',
        ]);
    }

    public function test_vk_login_existing_user_by_provider_id(): void
    {
        $user = User::factory()->create(['vk_id' => '12345']);
        $this->fakeVkUsersGet();

        $this->postJson($this->api('/auth/vk'), [
            'access_token' => 'vk-token',
            'email' => 'other@mail.ru',
        ])->assertOk()
            ->assertJsonPath('data.user.id', $user->id);

        // Email аккаунта провайдером не перезаписывается.
        $this->assertSame($user->email, $user->fresh()->email);
    }

    public function test_vk_login_email_collision_requires_confirmed_link(): void
    {
        $existing = User::factory()->create(['email' => 'ivan@mail.ru']);
        $this->fakeVkUsersGet();

        $this->postJson($this->api('/auth/vk'), [
            'access_token' => 'vk-token',
            'email' => 'ivan@mail.ru',
        ])->assertStatus(409)
            ->assertJsonPath('code', 'oauth_link_required');

        // Автопривязки нет: провайдер не проставлен, токен не выдан.
        $this->assertNull($existing->fresh()->vk_id);
        $this->assertDatabaseCount('personal_access_tokens', 0);
    }

    public function test_vk_login_invalid_provider_token(): void
    {
        Http::fake([
            'api.vk.com/method/users.get*' => Http::response([
                'error' => ['error_code' => 5, 'error_msg' => 'invalid token'],
            ], 200),
        ]);

        $this->postJson($this->api('/auth/vk'), [
            'access_token' => 'bad-token',
        ])->assertUnprocessable()
            ->assertJsonValidationErrors(['access_token']);
    }

    public function test_vk_login_requires_access_token(): void
    {
        $this->postJson($this->api('/auth/vk'), [])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['access_token']);
    }

    // ─── Yandex ───────────────────────────────────────────

    public function test_yandex_login_creates_user(): void
    {
        $this->fakeYandexUser();

        $this->postJson($this->api('/auth/yandex'), [
            'access_token' => 'ya-token',
        ])->assertOk()
            ->assertJsonStructure(['data' => ['token', 'user' => ['id', 'email']]])
            ->assertJsonPath('data.user.email', 'ivan@yandex.ru')
            ->assertJsonPath(
                'data.user.avatar_url',
                'https://avatars.yandex.net/get-yapic/x/islands-200',
            );

        $this->assertDatabaseHas('users', [
            'email' => 'ivan@yandex.ru',
            'yandex_id' => '777',
        ]);
    }

    public function test_yandex_login_existing_user_by_provider_id(): void
    {
        $user = User::factory()->create(['yandex_id' => '777']);
        $this->fakeYandexUser(['email' => 'other@yandex.ru']);

        $this->postJson($this->api('/auth/yandex'), [
            'access_token' => 'ya-token',
        ])->assertOk()
            ->assertJsonPath('data.user.id', $user->id);
    }

    public function test_yandex_login_email_collision_requires_confirmed_link(): void
    {
        $existing = User::factory()->create(['email' => 'ivan@yandex.ru']);
        $this->fakeYandexUser();

        $this->postJson($this->api('/auth/yandex'), [
            'access_token' => 'ya-token',
        ])->assertStatus(409)
            ->assertJsonPath('code', 'oauth_link_required');

        $this->assertNull($existing->fresh()->yandex_id);
    }

    public function test_yandex_login_invalid_provider_token(): void
    {
        $this->fakeYandexFailure();

        $this->postJson($this->api('/auth/yandex'), [
            'access_token' => 'bad-token',
        ])->assertUnprocessable()
            ->assertJsonValidationErrors(['access_token']);
    }

    // ─── Подтверждённая привязка ──────────────────────────

    public function test_link_requires_authentication(): void
    {
        $this->postJson($this->api('/auth/vk/link'), [
            'access_token' => 'vk-token',
        ])->assertUnauthorized();
    }

    public function test_vk_link_attaches_provider_to_current_user(): void
    {
        $user = User::factory()->create(['email' => 'ivan@mail.ru']);
        Sanctum::actingAs($user);
        $this->fakeVkUsersGet();

        $this->postJson($this->api('/auth/vk/link'), [
            'access_token' => 'vk-token',
        ])->assertOk()
            ->assertJsonPath('data.user.id', $user->id);

        $this->assertSame('12345', $user->fresh()->vk_id);
    }

    public function test_vk_link_is_idempotent(): void
    {
        $user = User::factory()->create(['vk_id' => '12345']);
        Sanctum::actingAs($user);
        $this->fakeVkUsersGet();

        $this->postJson($this->api('/auth/vk/link'), [
            'access_token' => 'vk-token',
        ])->assertOk();

        $this->assertSame('12345', $user->fresh()->vk_id);
    }

    public function test_vk_link_refuses_provider_bound_to_other_user(): void
    {
        User::factory()->create(['vk_id' => '12345']);
        $user = User::factory()->create();
        Sanctum::actingAs($user);
        $this->fakeVkUsersGet();

        $this->postJson($this->api('/auth/vk/link'), [
            'access_token' => 'vk-token',
        ])->assertStatus(409)
            ->assertJsonPath('code', 'oauth_provider_taken');

        $this->assertNull($user->fresh()->vk_id);
    }

    public function test_vk_link_refuses_rebinding_to_different_account(): void
    {
        $user = User::factory()->create(['vk_id' => '999']);
        Sanctum::actingAs($user);
        $this->fakeVkUsersGet(); // возвращает id 12345

        $this->postJson($this->api('/auth/vk/link'), [
            'access_token' => 'vk-token',
        ])->assertStatus(409)
            ->assertJsonPath('code', 'oauth_already_linked');

        $this->assertSame('999', $user->fresh()->vk_id);
    }

    public function test_yandex_link_attaches_provider(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);
        $this->fakeYandexUser();

        $this->postJson($this->api('/auth/yandex/link'), [
            'access_token' => 'ya-token',
        ])->assertOk();

        $this->assertSame('777', $user->fresh()->yandex_id);
    }
}
