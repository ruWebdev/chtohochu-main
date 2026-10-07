<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\WishList;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class WishListsApiTest extends TestCase
{
    use RefreshDatabase;

    private function actingUser(): User
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        return $user;
    }

    public function test_unauthenticated_rejected(): void
    {
        $list = WishList::factory()->create();

        $this->getJson($this->api('/wish-lists'))->assertUnauthorized();
        $this->postJson($this->api('/wish-lists'), ['title' => 'X'])->assertUnauthorized();
        $this->getJson($this->api("/wish-lists/{$list->id}"))->assertUnauthorized();
        $this->patchJson($this->api("/wish-lists/{$list->id}"), ['title' => 'X'])->assertUnauthorized();
        $this->deleteJson($this->api("/wish-lists/{$list->id}"))->assertUnauthorized();
    }

    public function test_user_can_create_list_owner_from_auth(): void
    {
        $user = $this->actingUser();
        $other = User::factory()->create();

        $this->postJson($this->api('/wish-lists'), [
            'id' => '3f2c1d9e-4a5b-4c6d-8e7f-9a0b1c2d3e4f',
            'title' => 'Подарки',
            'owner_id' => $other->id, // игнорируется
        ])->assertCreated()
            ->assertJsonPath('data.title', 'Подарки')
            ->assertJsonPath('data.id', '3f2c1d9e-4a5b-4c6d-8e7f-9a0b1c2d3e4f')
            ->assertJsonStructure(['data' => ['id', 'title', 'created_at', 'updated_at']]);

        $list = WishList::sole();
        $this->assertSame($user->id, $list->owner_id);
        $this->assertArrayNotHasKey('owner_id', $this->getJson($this->api("/wish-lists/{$list->id}"))->json('data'));
    }

    public function test_create_with_same_id_conflicts(): void
    {
        $user = $this->actingUser();
        $id = '3f2c1d9e-4a5b-4c6d-8e7f-9a0b1c2d3e4f';

        $this->postJson($this->api('/wish-lists'), ['id' => $id, 'title' => 'Первый'])
            ->assertCreated();

        // Повторный POST с той же identity — 409 (idempotent create);
        // серверная запись не дублируется.
        $this->postJson($this->api('/wish-lists'), ['id' => $id, 'title' => 'Первый'])
            ->assertConflict();
        $this->assertSame(1, WishList::where('owner_id', $user->id)->count());
    }

    public function test_list_title_validation(): void
    {
        $this->actingUser();

        $this->postJson($this->api('/wish-lists'), [])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['title']);

        $this->postJson($this->api('/wish-lists'), ['title' => str_repeat('a', 101)])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['title']);

        $this->postJson($this->api('/wish-lists'), ['id' => 'not-a-uuid', 'title' => 'X'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['id']);
    }

    public function test_user_lists_only_own_sorted_desc(): void
    {
        $user = $this->actingUser();
        WishList::factory()->create(['owner_id' => $user->id, 'title' => 'Старый', 'created_at' => now()->subDay()]);
        WishList::factory()->create(['owner_id' => $user->id, 'title' => 'Новый']);
        WishList::factory()->count(3)->create(); // чужие

        $response = $this->getJson($this->api('/wish-lists'))->assertOk();

        $this->assertCount(2, $response->json('data'));
        $this->assertSame('Новый', $response->json('data.0.title'));
        $this->assertSame('Старый', $response->json('data.1.title'));
    }

    public function test_show_update_delete_only_owner(): void
    {
        $this->actingUser();
        $foreign = WishList::factory()->create();

        // Чужой список — 404 (не раскрываем существование).
        $this->getJson($this->api("/wish-lists/{$foreign->id}"))->assertNotFound();
        $this->patchJson($this->api("/wish-lists/{$foreign->id}"), ['title' => 'X'])->assertNotFound();
        $this->deleteJson($this->api("/wish-lists/{$foreign->id}"))->assertNotFound();
    }

    public function test_update_own_list(): void
    {
        $user = $this->actingUser();
        $list = WishList::factory()->create(['owner_id' => $user->id, 'title' => 'Старое']);

        $this->patchJson($this->api("/wish-lists/{$list->id}"), ['title' => 'Новое'])
            ->assertOk()
            ->assertJsonPath('data.title', 'Новое');

        $this->assertSame('Новое', $list->fresh()->title);
    }

    public function test_delete_soft_deletes_and_excludes_from_index(): void
    {
        $user = $this->actingUser();
        $list = WishList::factory()->create(['owner_id' => $user->id]);

        $this->deleteJson($this->api("/wish-lists/{$list->id}"))->assertNoContent();

        // Soft delete: строка с tombstone, из index исключена.
        $this->assertSoftDeleted('wish_lists', ['id' => $list->id]);
        $this->assertCount(0, $this->getJson($this->api('/wish-lists'))->json('data'));
    }

    public function test_repeat_delete_not_found(): void
    {
        $user = $this->actingUser();
        $list = WishList::factory()->create(['owner_id' => $user->id]);

        $this->deleteJson($this->api("/wish-lists/{$list->id}"))->assertNoContent();

        // Повторный DELETE: soft-deleted строка не биндится в
        // маршрут → 404; клиентский sync считает delete выполненным.
        $this->deleteJson($this->api("/wish-lists/{$list->id}"))->assertNotFound();
    }
}
