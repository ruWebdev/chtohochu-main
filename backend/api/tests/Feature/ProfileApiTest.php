<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\Wish;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ProfileApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_patch_me_requires_authentication(): void
    {
        $this->patchJson($this->api('/me'), ['name' => 'X'])->assertUnauthorized();
    }

    public function test_user_can_update_name(): void
    {
        $user = User::factory()->create(['name' => 'Старое']);
        Sanctum::actingAs($user);

        $this->patchJson($this->api('/me'), ['name' => 'Новое имя'])
            ->assertOk()
            ->assertJsonPath('data.name', 'Новое имя');
    }

    public function test_user_can_set_and_update_username(): void
    {
        $user = User::factory()->create(['username' => null]);
        Sanctum::actingAs($user);

        $this->patchJson($this->api('/me'), ['username' => 'Ivan.Petrov'])
            ->assertOk()
            ->assertJsonPath('data.username', 'ivan.petrov'); // lowercase

        $this->patchJson($this->api('/me'), ['username' => 'ivan_2'])
            ->assertOk()
            ->assertJsonPath('data.username', 'ivan_2');
    }

    public function test_patch_me_rejects_invalid_username(): void
    {
        Sanctum::actingAs(User::factory()->create());

        foreach (['AB', 'a b', 'u!', 'x'.str_repeat('y', 30)] as $username) {
            $this->patchJson($this->api('/me'), ['username' => $username])
                ->assertUnprocessable()
                ->assertJsonValidationErrors(['username']);
        }
    }

    public function test_patch_me_rejects_taken_username(): void
    {
        User::factory()->create(['username' => 'taken']);
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $this->patchJson($this->api('/me'), ['username' => 'Taken'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['username']);
    }

    public function test_patch_me_allows_keeping_own_username(): void
    {
        $user = User::factory()->create(['username' => 'mine']);
        Sanctum::actingAs($user);

        $this->patchJson($this->api('/me'), ['username' => 'mine', 'name' => 'Обновлён'])
            ->assertOk()
            ->assertJsonPath('data.username', 'mine')
            ->assertJsonPath('data.name', 'Обновлён');
    }

    public function test_nullable_fields_can_be_cleared_with_null(): void
    {
        $user = User::factory()->create([
            'username' => 'ivan',
            'avatar_url' => 'https://example.com/a.png',
        ]);
        Sanctum::actingAs($user);

        $this->patchJson($this->api('/me'), ['username' => null, 'avatar_url' => null])
            ->assertOk()
            ->assertJsonPath('data.username', null)
            ->assertJsonPath('data.avatar_url', null);

        $this->assertNull($user->fresh()->username);
        $this->assertNull($user->fresh()->avatar_url);
    }

    public function test_patch_me_rejects_invalid_avatar_url(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->patchJson($this->api('/me'), ['avatar_url' => 'not a url'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['avatar_url']);
    }

    public function test_email_and_password_cannot_be_changed_via_patch_me(): void
    {
        $user = User::factory()->create(['email' => 'me@example.com', 'password' => 'password123']);
        $hash = $user->password;
        Sanctum::actingAs($user);

        $this->patchJson($this->api('/me'), [
            'email' => 'hacked@example.com',
            'password' => 'newpassword999',
            'name' => 'Легальное',
        ])->assertOk();

        $fresh = $user->fresh();
        $this->assertSame('me@example.com', $fresh->email);
        $this->assertSame($hash, $fresh->password);
        $this->assertSame('Легальное', $fresh->name);
    }

    public function test_has_wishes_meta_reflects_actual_wishes(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $this->getJson($this->api('/me'))->assertJsonPath('meta.has_wishes', false);

        Wish::factory()->create(['owner_id' => $user->id]);

        $this->getJson($this->api('/me'))->assertJsonPath('meta.has_wishes', true);
    }
}
