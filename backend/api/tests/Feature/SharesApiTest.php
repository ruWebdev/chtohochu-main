<?php

namespace Tests\Feature;

use App\Models\Share;
use App\Models\User;
use App\Models\Wish;
use App\Models\WishList;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class SharesApiTest extends TestCase
{
    use RefreshDatabase;

    private function actingUser(): User
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        return $user;
    }

    // ---------- Wish share ----------

    public function test_owner_can_share_wish(): void
    {
        $user = $this->actingUser();
        $wish = Wish::factory()->for($user, 'owner')->create();

        $response = $this->postJson($this->api("/wishes/{$wish->id}/share"))
            ->assertCreated()
            ->assertJsonStructure(['data' => ['token', 'url']]);

        $token = $response->json('data.token');
        // Capability token ≠ UUID сущности, серверный random.
        $this->assertNotSame($wish->id, $token);
        $this->assertSame(43, strlen($token));
        $this->assertStringEndsWith('/s/'.$token, $response->json('data.url'));

        $share = Share::sole();
        $this->assertSame($user->id, $share->owner_id);
        $this->assertSame(Wish::class, $share->shareable_type);
        $this->assertSame($wish->id, $share->shareable_id);
        $this->assertNull($share->revoked_at);
    }

    public function test_share_wish_is_idempotent(): void
    {
        $user = $this->actingUser();
        $wish = Wish::factory()->for($user, 'owner')->create();

        $first = $this->postJson($this->api("/wishes/{$wish->id}/share"))->json('data.token');
        $second = $this->postJson($this->api("/wishes/{$wish->id}/share"))->json('data.token');

        $this->assertSame($first, $second);
        $this->assertSame(1, Share::count());
    }

    public function test_share_wish_only_owner(): void
    {
        $this->actingUser();
        $foreign = Wish::factory()->create();

        // Чужое желание — 404, существование не раскрывается.
        $this->postJson($this->api("/wishes/{$foreign->id}/share"))->assertNotFound();
        $this->assertSame(0, Share::count());
    }

    public function test_share_deleted_wish_not_found(): void
    {
        $user = $this->actingUser();
        $wish = Wish::factory()->for($user, 'owner')->create();

        $this->deleteJson($this->api("/wishes/{$wish->id}"))->assertNoContent();
        $this->postJson($this->api("/wishes/{$wish->id}/share"))->assertNotFound();
    }

    public function test_share_wish_requires_auth(): void
    {
        $wish = Wish::factory()->create();
        $this->postJson($this->api("/wishes/{$wish->id}/share"))->assertUnauthorized();
    }

    // ---------- WishList share ----------

    public function test_owner_can_share_wish_list(): void
    {
        $user = $this->actingUser();
        $list = WishList::factory()->for($user, 'owner')->create();

        $response = $this->postJson($this->api("/wish-lists/{$list->id}/share"))
            ->assertCreated()
            ->assertJsonStructure(['data' => ['token', 'url']]);

        $this->assertNotSame($list->id, $response->json('data.token'));
        $this->assertSame(
            WishList::class,
            Share::sole()->shareable_type
        );
    }

    public function test_share_wish_list_is_idempotent(): void
    {
        $user = $this->actingUser();
        $list = WishList::factory()->for($user, 'owner')->create();

        $first = $this->postJson($this->api("/wish-lists/{$list->id}/share"))->json('data.token');
        $second = $this->postJson($this->api("/wish-lists/{$list->id}/share"))->json('data.token');

        $this->assertSame($first, $second);
        $this->assertSame(1, Share::count());
    }

    public function test_share_wish_list_only_owner(): void
    {
        $this->actingUser();
        $foreign = WishList::factory()->create();

        $this->postJson($this->api("/wish-lists/{$foreign->id}/share"))->assertNotFound();
        $this->assertSame(0, Share::count());
    }

    public function test_share_deleted_wish_list_not_found(): void
    {
        $user = $this->actingUser();
        $list = WishList::factory()->for($user, 'owner')->create();

        $this->deleteJson($this->api("/wish-lists/{$list->id}"))->assertNoContent();
        $this->postJson($this->api("/wish-lists/{$list->id}/share"))->assertNotFound();
    }

    // ---------- Revoke ----------

    public function test_owner_can_revoke_share(): void
    {
        $user = $this->actingUser();
        $wish = Wish::factory()->for($user, 'owner')->create();
        $this->postJson($this->api("/wishes/{$wish->id}/share"))->assertCreated();
        $share = Share::sole();

        $this->deleteJson($this->api("/shares/{$share->id}"))->assertNoContent();
        $this->assertNotNull($share->fresh()->revoked_at);

        // Revoked share больше не резолвится публично.
        $this->getJson($this->api("/share/{$share->token}"))->assertNotFound();

        // Повторный revoke безопасен (строка жива, идемпотентно).
        $this->deleteJson($this->api("/shares/{$share->id}"))->assertNoContent();
    }

    public function test_revoke_only_owner(): void
    {
        $this->actingUser();
        $share = Share::factory()->create([
            'shareable_type' => Wish::class,
            'shareable_id' => Wish::factory()->create()->id,
        ]);

        $this->deleteJson($this->api("/shares/{$share->id}"))->assertNotFound();
        $this->assertNull($share->fresh()->revoked_at);
    }

    // ---------- Public resolver ----------

    public function test_public_wish_share_minimal_projection(): void
    {
        $owner = User::factory()->create(['name' => 'Наташа']);
        $wish = Wish::factory()->for($owner, 'owner')->create([
            'title' => 'Наушники',
            'description' => 'Секретная заметка',
            'price' => 12990,
            'link' => 'https://example.com/item',
        ]);
        Sanctum::actingAs($owner);
        $token = $this->postJson($this->api("/wishes/{$wish->id}/share"))->json('data.token');

        // Анонимный запрос — без Sanctum-токена.
        Sanctum::actingAs(User::factory()->create());
        $data = $this->getJson($this->api("/share/{$token}"))
            ->assertOk()
            ->assertHeader('Cache-Control', 'no-store, private')
            ->json('data');

        $this->assertSame('wish', $this->getJson($this->api("/share/{$token}"))->json('type'));
        $this->assertSame('Наушники', $data['title']);
        $this->assertSame(12990, $data['price']);
        $this->assertSame('Наташа', $data['owner']['name']);

        // Privacy: нет id, owner_id, email, username, note, timestamps.
        foreach (['id', 'list_id', 'owner_id', 'email', 'username', 'description', 'created_at', 'updated_at', 'deleted_at'] as $key) {
            $this->assertArrayNotHasKey($key, $data, "leaked: {$key}");
        }
        $this->assertArrayNotHasKey('email', $data['owner']);
        $this->assertArrayNotHasKey('username', $data['owner']);
        $this->assertArrayNotHasKey('id', $data['owner']);
    }

    public function test_public_wish_list_share_projection(): void
    {
        $owner = User::factory()->create(['name' => 'Иван']);
        $list = WishList::factory()->for($owner, 'owner')->create(['title' => 'Техника']);
        Wish::factory()->for($owner, 'owner')->create([
            'list_id' => $list->id,
            'title' => 'Лампа',
            'description' => 'Не для чужих',
            'created_at' => now()->subHour(),
        ]);
        Wish::factory()->for($owner, 'owner')->create([
            'list_id' => $list->id,
            'title' => 'Кресло',
        ]);
        // Желание вне списка в публичный список не попадает.
        Wish::factory()->for($owner, 'owner')->create(['title' => 'Приватное']);
        Sanctum::actingAs($owner);
        $token = $this->postJson($this->api("/wish-lists/{$list->id}/share"))->json('data.token');

        $response = $this->getJson($this->api("/share/{$token}"))->assertOk();
        $this->assertSame('wish_list', $response->json('type'));

        $data = $response->json('data');
        $this->assertSame('Техника', $data['title']);
        $this->assertSame('Иван', $data['owner']['name']);
        $this->assertCount(2, $data['wishes']);
        $this->assertSame('Кресло', $data['wishes'][0]['title']); // created_at DESC

        foreach ($data['wishes'] as $wish) {
            foreach (['id', 'list_id', 'owner_id', 'description', 'created_at', 'updated_at', 'deleted_at', 'owner'] as $key) {
                $this->assertArrayNotHasKey($key, $wish, "leaked: {$key}");
            }
        }
        foreach (['id', 'owner_id', 'created_at', 'updated_at', 'deleted_at'] as $key) {
            $this->assertArrayNotHasKey($key, $data, "leaked: {$key}");
        }
    }

    public function test_public_invalid_token_not_found(): void
    {
        $this->getJson($this->api('/share/nonexistent-token'))->assertNotFound();
    }

    public function test_public_share_of_deleted_wish_not_found(): void
    {
        $user = $this->actingUser();
        $wish = Wish::factory()->for($user, 'owner')->create();
        $token = $this->postJson($this->api("/wishes/{$wish->id}/share"))->json('data.token');

        $this->assertSame(200, $this->getJson($this->api("/share/{$token}"))->status());

        $wish->delete();
        $this->getJson($this->api("/share/{$token}"))->assertNotFound();
    }

    public function test_public_share_of_soft_deleted_list_not_found(): void
    {
        $user = $this->actingUser();
        $list = WishList::factory()->for($user, 'owner')->create();
        $token = $this->postJson($this->api("/wish-lists/{$list->id}/share"))->json('data.token');

        $list->delete();
        $this->getJson($this->api("/share/{$token}"))->assertNotFound();
    }

    public function test_public_wish_list_no_n_plus_one(): void
    {
        $owner = User::factory()->create();
        $list = WishList::factory()->for($owner, 'owner')->create();
        Wish::factory()->for($owner, 'owner')->count(10)->create(['list_id' => $list->id]);
        Sanctum::actingAs($owner);
        $token = $this->postJson($this->api("/wish-lists/{$list->id}/share"))->json('data.token');

        // Eager load: share + list + owner + wishes — константное
        // число запросов независимо от количества желаний.
        DB::enableQueryLog();
        DB::flushQueryLog();
        $this->getJson($this->api("/share/{$token}"))->assertOk();
        $this->assertLessThanOrEqual(6, count(DB::getQueryLog()));
        DB::disableQueryLog();
    }
}
