<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\Wish;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class WishApiTest extends TestCase
{
    use RefreshDatabase;

    private function actingUser(): User
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        return $user;
    }

    public function test_unauthenticated_cannot_use_wishes_endpoints(): void
    {
        $wish = Wish::factory()->create();

        $this->getJson($this->api('/wishes'))->assertUnauthorized();
        $this->postJson($this->api('/wishes'), ['title' => 'X'])->assertUnauthorized();
        $this->getJson($this->api("/wishes/{$wish->id}"))->assertUnauthorized();
        $this->patchJson($this->api("/wishes/{$wish->id}"), ['title' => 'Y'])->assertUnauthorized();
        $this->deleteJson($this->api("/wishes/{$wish->id}"))->assertUnauthorized();
    }

    public function test_user_can_list_only_own_wishes(): void
    {
        $user = $this->actingUser();
        Wish::factory()->count(2)->create(['owner_id' => $user->id]);
        Wish::factory()->count(3)->create(); // чужие

        $response = $this->getJson($this->api('/wishes'))->assertOk();

        $this->assertCount(2, $response->json('data'));
    }

    public function test_wishes_list_is_sorted_created_at_desc(): void
    {
        $user = $this->actingUser();
        $old = Wish::factory()->create([
            'owner_id' => $user->id,
            'title' => 'Старое',
            'created_at' => now()->subDay(),
        ]);
        $new = Wish::factory()->create([
            'owner_id' => $user->id,
            'title' => 'Новое',
            'created_at' => now(),
        ]);

        $response = $this->getJson($this->api('/wishes'));

        $this->assertSame($new->id, $response->json('data.0.id'));
        $this->assertSame($old->id, $response->json('data.1.id'));
    }

    public function test_user_can_create_wish_with_all_fields(): void
    {
        $user = $this->actingUser();

        $this->postJson($this->api('/wishes'), [
            'title' => 'Наушники Sony',
            'description' => 'Чёрные',
            'price' => 12990,
            'link' => 'https://example.com/product',
            'image_url' => 'https://example.com/img.png',
        ])->assertCreated()
            ->assertJsonPath('data.title', 'Наушники Sony')
            ->assertJsonPath('data.description', 'Чёрные')
            ->assertJsonPath('data.price', 12990)
            ->assertJsonPath('data.link', 'https://example.com/product')
            ->assertJsonPath('data.image_url', 'https://example.com/img.png')
            ->assertJsonStructure(['data' => ['id', 'created_at', 'updated_at']]);

        $wish = Wish::sole();
        $this->assertSame($user->id, $wish->owner_id);
    }

    public function test_wish_response_does_not_expose_owner_id(): void
    {
        $this->actingUser();

        $response = $this->postJson($this->api('/wishes'), ['title' => 'Тест'])->assertCreated();

        $this->assertArrayNotHasKey('owner_id', $response->json('data'));
    }

    public function test_client_cannot_assign_another_owner(): void
    {
        $user = $this->actingUser();
        $other = User::factory()->create();

        $this->postJson($this->api('/wishes'), [
            'title' => 'Подарок',
            'owner_id' => $other->id,
        ])->assertCreated();

        $this->assertSame($user->id, Wish::sole()->owner_id);
    }

    public function test_create_wish_validates_title(): void
    {
        $this->actingUser();

        $this->postJson($this->api('/wishes'), [])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['title']);

        $this->postJson($this->api('/wishes'), ['title' => str_repeat('a', 101)])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['title']);
    }

    public function test_create_wish_validates_price_and_urls(): void
    {
        $this->actingUser();

        $this->postJson($this->api('/wishes'), [
            'title' => 'X',
            'price' => -5,
        ])->assertUnprocessable()
            ->assertJsonValidationErrors(['price']);

        $this->postJson($this->api('/wishes'), [
            'title' => 'X',
            'price' => 'дорого',
        ])->assertUnprocessable()
            ->assertJsonValidationErrors(['price']);

        $this->postJson($this->api('/wishes'), [
            'title' => 'X',
            'link' => 'не ссылка',
            'image_url' => 'тоже не ссылка',
        ])->assertUnprocessable()
            ->assertJsonValidationErrors(['link', 'image_url']);
    }

    public function test_optional_fields_can_be_omitted(): void
    {
        $this->actingUser();

        $this->postJson($this->api('/wishes'), ['title' => 'Минимум'])
            ->assertCreated()
            ->assertJsonPath('data.description', null)
            ->assertJsonPath('data.price', null)
            ->assertJsonPath('data.link', null)
            ->assertJsonPath('data.image_url', null);
    }

    public function test_owner_can_view_own_wish(): void
    {
        $user = $this->actingUser();
        $wish = Wish::factory()->create(['owner_id' => $user->id]);

        $this->getJson($this->api("/wishes/{$wish->id}"))
            ->assertOk()
            ->assertJsonPath('data.id', $wish->id)
            ->assertJsonPath('data.title', $wish->title);
    }

    public function test_owner_can_update_own_wish(): void
    {
        $user = $this->actingUser();
        $wish = Wish::factory()->create(['owner_id' => $user->id, 'title' => 'Было']);

        $this->patchJson($this->api("/wishes/{$wish->id}"), [
            'title' => 'Стало',
            'price' => 500,
        ])->assertOk()
            ->assertJsonPath('data.title', 'Стало')
            ->assertJsonPath('data.price', 500);
    }

    public function test_owner_can_clear_nullable_fields(): void
    {
        $user = $this->actingUser();
        $wish = Wish::factory()->create([
            'owner_id' => $user->id,
            'description' => 'Есть',
            'price' => 100,
        ]);

        $this->patchJson($this->api("/wishes/{$wish->id}"), [
            'description' => null,
            'price' => null,
        ])->assertOk()
            ->assertJsonPath('data.description', null)
            ->assertJsonPath('data.price', null);
    }

    public function test_owner_cannot_change_owner_via_update(): void
    {
        $user = $this->actingUser();
        $other = User::factory()->create();
        $wish = Wish::factory()->create(['owner_id' => $user->id]);

        $this->patchJson($this->api("/wishes/{$wish->id}"), [
            'title' => 'Обновлён',
            'owner_id' => $other->id,
        ])->assertOk();

        $this->assertSame($user->id, $wish->fresh()->owner_id);
    }

    public function test_owner_can_delete_own_wish(): void
    {
        $user = $this->actingUser();
        $wish = Wish::factory()->create(['owner_id' => $user->id]);

        $this->deleteJson($this->api("/wishes/{$wish->id}"))->assertNoContent();
        $this->assertDatabaseMissing('wishes', ['id' => $wish->id]);
    }

    public function test_stranger_cannot_view_wish(): void
    {
        $this->actingUser();
        $wish = Wish::factory()->create(); // чужой владелец

        $this->getJson($this->api("/wishes/{$wish->id}"))->assertNotFound();
    }

    public function test_stranger_cannot_update_wish(): void
    {
        $this->actingUser();
        $wish = Wish::factory()->create(['title' => 'Нетронутый']);

        $this->patchJson($this->api("/wishes/{$wish->id}"), ['title' => 'Взломан'])
            ->assertNotFound();

        $this->assertSame('Нетронутый', $wish->fresh()->title);
    }

    public function test_stranger_cannot_delete_wish(): void
    {
        $this->actingUser();
        $wish = Wish::factory()->create();

        $this->deleteJson($this->api("/wishes/{$wish->id}"))->assertNotFound();
        $this->assertDatabaseHas('wishes', ['id' => $wish->id]);
    }

    public function test_nonexistent_wish_returns_404(): void
    {
        $this->actingUser();

        $this->getJson($this->api('/wishes/'.fake()->uuid()))->assertNotFound();
    }

    public function test_deleting_user_cascades_wishes(): void
    {
        $user = User::factory()->create();
        Wish::factory()->count(2)->create(['owner_id' => $user->id]);

        $user->delete();

        $this->assertDatabaseCount('wishes', 0);
    }

    // ── Client-generated UUID (offline-first) ────────────────

    public function test_create_wish_accepts_client_uuid(): void
    {
        $this->actingUser();
        $id = fake()->uuid();

        $this->postJson($this->api('/wishes'), [
            'id' => $id,
            'title' => 'Оффлайн желание',
        ])->assertCreated()
            ->assertJsonPath('data.id', $id);

        $this->assertDatabaseHas('wishes', ['id' => $id, 'title' => 'Оффлайн желание']);
    }

    public function test_create_wish_without_id_generates_server_uuid(): void
    {
        $this->actingUser();

        $response = $this->postJson($this->api('/wishes'), ['title' => 'Обычное'])
            ->assertCreated();

        $this->assertNotNull($response->json('data.id'));
        $this->assertSame(1, preg_match('/^[0-9a-f-]{36}$/i', $response->json('data.id')));
    }

    public function test_create_wish_rejects_invalid_uuid(): void
    {
        $this->actingUser();

        $this->postJson($this->api('/wishes'), [
            'id' => 'not-a-uuid',
            'title' => 'X',
        ])->assertUnprocessable()
            ->assertJsonValidationErrorFor('id');
    }

    public function test_create_wish_duplicate_uuid_returns_409(): void
    {
        $user = $this->actingUser();
        $id = fake()->uuid();

        $this->postJson($this->api('/wishes'), ['id' => $id, 'title' => 'A'])
            ->assertCreated();

        // Retry после потерянного ответа — та же identity, без дубликата.
        $this->postJson($this->api('/wishes'), ['id' => $id, 'title' => 'A'])
            ->assertConflict()
            ->assertJsonPath('message', 'Resource already exists.');

        $this->assertSame(1, Wish::where('id', $id)->count());
        $this->assertSame($user->id, Wish::sole()->owner_id);
    }

    public function test_create_wish_duplicate_uuid_from_other_user_still_409(): void
    {
        // UUID занят чужим ресурсом → 409 без утечки данных/ownership.
        Wish::factory()->create(['id' => fake()->uuid()]);
        $taken = Wish::sole()->id;

        $user = $this->actingUser();

        $response = $this->postJson($this->api('/wishes'), ['id' => $taken, 'title' => 'Чужой id'])
            ->assertConflict()
            ->assertJsonPath('message', 'Resource already exists.');

        $this->assertArrayNotHasKey('data', $response->json());

        $this->assertSame(1, Wish::where('id', $taken)->count());
        $this->assertNotSame($user->id, Wish::find($taken)->owner_id);
    }

    public function test_client_uuid_does_not_change_owner(): void
    {
        $user = $this->actingUser();
        $other = User::factory()->create();
        $id = fake()->uuid();

        $this->postJson($this->api('/wishes'), [
            'id' => $id,
            'owner_id' => $other->id,
            'title' => 'С чужим owner',
        ])->assertCreated();

        $wish = Wish::findOrFail($id);
        $this->assertSame($user->id, $wish->owner_id);
    }
}
