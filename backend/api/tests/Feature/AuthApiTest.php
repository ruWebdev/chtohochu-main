<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AuthApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_registration_succeeds_and_returns_token_and_user(): void
    {
        $response = $this->postJson($this->api('/auth/register'), [
            'email' => 'User@Example.com',
            'password' => 'password123',
            'password_confirmation' => 'password123',
            'name' => 'Иван',
        ]);

        $response->assertCreated()
            ->assertJsonStructure([
                'data' => [
                    'token',
                    'user' => ['id', 'email', 'name', 'username', 'avatar_url', 'created_at', 'updated_at'],
                ],
            ]);

        $this->assertDatabaseHas('users', ['email' => 'user@example.com', 'name' => 'Иван']);
        $this->assertDatabaseCount('personal_access_tokens', 1);
    }

    public function test_registration_requires_valid_data(): void
    {
        $this->postJson($this->api('/auth/register'), [])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['email', 'password']);

        $this->postJson($this->api('/auth/register'), [
            'email' => 'not-an-email',
            'password' => 'short',
            'password_confirmation' => 'short',
        ])->assertUnprocessable()
            ->assertJsonValidationErrors(['email', 'password']);

        $this->postJson($this->api('/auth/register'), [
            'email' => 'a@example.com',
            'password' => 'password123',
            'password_confirmation' => 'different123',
        ])->assertUnprocessable()
            ->assertJsonValidationErrors(['password']);
    }

    public function test_duplicate_email_fails_registration(): void
    {
        User::factory()->create(['email' => 'taken@example.com']);

        $this->postJson($this->api('/auth/register'), [
            'email' => 'taken@example.com',
            'password' => 'password123',
            'password_confirmation' => 'password123',
        ])->assertUnprocessable()
            ->assertJsonValidationErrors(['email']);
    }

    public function test_email_uniqueness_is_case_insensitive(): void
    {
        User::factory()->create(['email' => 'Taken@Example.com']);

        $this->postJson($this->api('/auth/register'), [
            'email' => 'taken@example.com',
            'password' => 'password123',
            'password_confirmation' => 'password123',
        ])->assertUnprocessable()
            ->assertJsonValidationErrors(['email']);
    }

    public function test_registration_rejects_invalid_username(): void
    {
        foreach (['AB', 'a b', 'user!', 'xx', 'waytoolongusername_1234', 'Кириллица'] as $username) {
            $this->postJson($this->api('/auth/register'), [
                'email' => 'u'.md5($username).'@example.com',
                'password' => 'password123',
                'password_confirmation' => 'password123',
                'username' => $username,
            ])->assertUnprocessable()
                ->assertJsonValidationErrors(['username']);
        }
    }

    public function test_duplicate_username_fails(): void
    {
        User::factory()->create(['username' => 'ivan']);

        $this->postJson($this->api('/auth/register'), [
            'email' => 'new@example.com',
            'password' => 'password123',
            'password_confirmation' => 'password123',
            'username' => 'Ivan',
        ])->assertUnprocessable()
            ->assertJsonValidationErrors(['username']);
    }

    public function test_login_succeeds_case_insensitive_email(): void
    {
        User::factory()->create(['email' => 'user@example.com', 'password' => 'password123']);

        $this->postJson($this->api('/auth/login'), [
            'email' => 'USER@example.com',
            'password' => 'password123',
        ])->assertOk()
            ->assertJsonStructure(['data' => ['token', 'user' => ['id', 'email']]]);
    }

    public function test_login_fails_with_invalid_credentials_without_revealing_email(): void
    {
        User::factory()->create(['email' => 'user@example.com', 'password' => 'password123']);

        $this->postJson($this->api('/auth/login'), [
            'email' => 'user@example.com',
            'password' => 'wrong-password',
        ])->assertUnauthorized()
            ->assertExactJson(['message' => 'Invalid credentials.']);

        $this->postJson($this->api('/auth/login'), [
            'email' => 'nobody@example.com',
            'password' => 'password123',
        ])->assertUnauthorized()
            ->assertExactJson(['message' => 'Invalid credentials.']);
    }

    public function test_me_requires_authentication(): void
    {
        $this->getJson($this->api('/me'))
            ->assertUnauthorized()
            ->assertExactJson(['message' => 'Unauthenticated.']);
    }

    public function test_me_returns_current_user_with_meta(): void
    {
        $user = User::factory()->create(['username' => 'ivan', 'avatar_url' => 'https://example.com/a.png']);
        Sanctum::actingAs($user);

        $this->getJson($this->api('/me'))
            ->assertOk()
            ->assertJsonPath('data.id', $user->id)
            ->assertJsonPath('data.email', $user->email)
            ->assertJsonPath('data.username', 'ivan')
            ->assertJsonPath('data.avatar_url', 'https://example.com/a.png')
            ->assertJsonPath('meta.has_wishes', false);
    }

    public function test_me_does_not_expose_password(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $response = $this->getJson($this->api('/me'))->assertOk();

        $this->assertArrayNotHasKey('password', $response->json('data'));
    }

    public function test_logout_revokes_only_current_token(): void
    {
        $user = User::factory()->create(['password' => 'password123']);

        $token1 = $user->createToken('api')->plainTextToken;
        $token2 = $user->createToken('api')->plainTextToken;

        $this->withToken($token1)->postJson($this->api('/auth/logout'))->assertNoContent();

        $this->assertDatabaseCount('personal_access_tokens', 1);

        // Сбрасываем memoized guard — иначе в пределах одного
        // test-app следующий запрос получит закешированного user.
        $this->app->make('auth')->forgetGuards();

        // Отозванный токен больше не работает.
        $this->withToken($token1)->getJson($this->api('/me'))->assertUnauthorized();

        // Другой токен того же пользователя продолжает работать.
        $this->withToken($token2)->getJson($this->api('/me'))->assertOk();
    }

    public function test_logout_requires_authentication(): void
    {
        $this->postJson($this->api('/auth/logout'))->assertUnauthorized();
    }
}
