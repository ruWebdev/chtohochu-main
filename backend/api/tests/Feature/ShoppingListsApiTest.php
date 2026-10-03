<?php

namespace Tests\Feature;

use App\Models\ShoppingItem;
use App\Models\ShoppingList;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ShoppingListsApiTest extends TestCase
{
    use RefreshDatabase;

    private function actingUser(): User
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        return $user;
    }

    // ── Lists ───────────────────────────────────────────────

    public function test_unauthenticated_rejected(): void
    {
        $list = ShoppingList::factory()->create();
        $item = ShoppingItem::factory()->create();

        $this->getJson($this->api('/shopping-lists'))->assertUnauthorized();
        $this->postJson($this->api('/shopping-lists'), ['title' => 'X'])->assertUnauthorized();
        $this->getJson($this->api("/shopping-lists/{$list->id}"))->assertUnauthorized();
        $this->postJson($this->api("/shopping-lists/{$list->id}/items"), ['title' => 'X'])->assertUnauthorized();
        $this->patchJson($this->api("/shopping-items/{$item->id}"), ['title' => 'X'])->assertUnauthorized();
        $this->deleteJson($this->api("/shopping-items/{$item->id}"))->assertUnauthorized();
    }

    public function test_user_can_create_list_owner_from_auth(): void
    {
        $user = $this->actingUser();
        $other = User::factory()->create();

        $this->postJson($this->api('/shopping-lists'), [
            'title' => 'Продукты',
            'owner_id' => $other->id, // игнорируется
        ])->assertCreated()
            ->assertJsonPath('data.title', 'Продукты')
            ->assertJsonStructure(['data' => ['id', 'title', 'items', 'created_at', 'updated_at']]);

        $list = ShoppingList::sole();
        $this->assertSame($user->id, $list->owner_id);
        $this->assertArrayNotHasKey('owner_id', $this->getJson($this->api("/shopping-lists/{$list->id}"))->json('data'));
    }

    public function test_list_title_validation(): void
    {
        $this->actingUser();

        $this->postJson($this->api('/shopping-lists'), [])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['title']);

        $this->postJson($this->api('/shopping-lists'), ['title' => str_repeat('a', 101)])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['title']);
    }

    public function test_user_lists_only_own_with_items_sorted_desc(): void
    {
        $user = $this->actingUser();
        $old = ShoppingList::factory()->create(['owner_id' => $user->id, 'title' => 'Старый', 'created_at' => now()->subDay()]);
        $new = ShoppingList::factory()->create(['owner_id' => $user->id, 'title' => 'Новый']);
        ShoppingItem::factory()->count(2)->create(['list_id' => $new->id]);
        ShoppingList::factory()->count(3)->create(); // чужие

        $response = $this->getJson($this->api('/shopping-lists'))->assertOk();

        $this->assertCount(2, $response->json('data'));
        $this->assertSame($new->id, $response->json('data.0.id'));
        $this->assertSame($old->id, $response->json('data.1.id'));
        $this->assertCount(2, $response->json('data.0.items'));
        $this->assertSame([], $response->json('data.1.items'));
    }

    public function test_lists_index_does_not_n_plus_1(): void
    {
        $user = $this->actingUser();
        $lists = ShoppingList::factory()->count(5)->create(['owner_id' => $user->id]);
        foreach ($lists as $l) {
            ShoppingItem::factory()->count(3)->create(['list_id' => $l->id]);
        }

        $queries = 0;
        DB::listen(fn () => $queries++);

        $this->getJson($this->api('/shopping-lists'))->assertOk();

        // 1 запрос lists + 1 запрос items (eager), без N+1.
        $this->assertLessThanOrEqual(3, $queries);
    }

    public function test_user_can_get_own_list(): void
    {
        $user = $this->actingUser();
        $list = ShoppingList::factory()->create(['owner_id' => $user->id]);
        ShoppingItem::factory()->create(['list_id' => $list->id, 'title' => 'Молоко']);

        $this->getJson($this->api("/shopping-lists/{$list->id}"))
            ->assertOk()
            ->assertJsonPath('data.id', $list->id)
            ->assertJsonPath('data.items.0.title', 'Молоко');
    }

    public function test_user_can_rename_own_list(): void
    {
        $user = $this->actingUser();
        $list = ShoppingList::factory()->create(['owner_id' => $user->id, 'title' => 'Было']);

        $this->patchJson($this->api("/shopping-lists/{$list->id}"), ['title' => 'Стало'])
            ->assertOk()
            ->assertJsonPath('data.title', 'Стало');
    }

    public function test_list_update_ignores_owner_and_items(): void
    {
        $user = $this->actingUser();
        $other = User::factory()->create();
        $list = ShoppingList::factory()->create(['owner_id' => $user->id]);

        $this->patchJson($this->api("/shopping-lists/{$list->id}"), [
            'title' => 'Ок',
            'owner_id' => $other->id,
            'items' => [['title' => 'Подмена']],
            'created_at' => '2000-01-01',
        ])->assertOk();

        $fresh = $list->fresh();
        $this->assertSame($user->id, $fresh->owner_id);
        $this->assertDatabaseCount('shopping_items', 0);
    }

    public function test_user_can_delete_own_list_cascading_items(): void
    {
        $user = $this->actingUser();
        $list = ShoppingList::factory()->create(['owner_id' => $user->id]);
        ShoppingItem::factory()->count(2)->create(['list_id' => $list->id]);

        $this->deleteJson($this->api("/shopping-lists/{$list->id}"))->assertNoContent();

        $this->assertDatabaseMissing('shopping_lists', ['id' => $list->id]);
        $this->assertDatabaseCount('shopping_items', 0);
    }

    // ── Items ───────────────────────────────────────────────

    public function test_owner_can_create_item_with_defaults(): void
    {
        $user = $this->actingUser();
        $list = ShoppingList::factory()->create(['owner_id' => $user->id]);

        $this->postJson($this->api("/shopping-lists/{$list->id}/items"), ['title' => 'Молоко'])
            ->assertCreated()
            ->assertJsonPath('data.title', 'Молоко')
            ->assertJsonPath('data.quantity', 1)
            ->assertJsonPath('data.is_checked', false);

        $this->assertSame($list->id, ShoppingItem::sole()->list_id);
    }

    public function test_item_create_with_quantity(): void
    {
        $user = $this->actingUser();
        $list = ShoppingList::factory()->create(['owner_id' => $user->id]);

        $this->postJson($this->api("/shopping-lists/{$list->id}/items"), ['title' => 'Яйца', 'quantity' => 10])
            ->assertCreated()
            ->assertJsonPath('data.quantity', 10);
    }

    public function test_item_validation(): void
    {
        $user = $this->actingUser();
        $list = ShoppingList::factory()->create(['owner_id' => $user->id]);

        $this->postJson($this->api("/shopping-lists/{$list->id}/items"), [])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['title']);

        $this->postJson($this->api("/shopping-lists/{$list->id}/items"), ['title' => str_repeat('a', 201)])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['title']);

        $this->postJson($this->api("/shopping-lists/{$list->id}/items"), ['title' => 'X', 'quantity' => 0])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['quantity']);
    }

    public function test_owner_can_update_item_fields(): void
    {
        $user = $this->actingUser();
        $list = ShoppingList::factory()->create(['owner_id' => $user->id]);
        $item = ShoppingItem::factory()->create(['list_id' => $list->id]);

        $this->patchJson($this->api("/shopping-items/{$item->id}"), ['is_checked' => true])
            ->assertOk()
            ->assertJsonPath('data.is_checked', true);

        $this->patchJson($this->api("/shopping-items/{$item->id}"), [
            'title' => 'Молоко 2.5%',
            'quantity' => 3,
        ])->assertOk()
            ->assertJsonPath('data.title', 'Молоко 2.5%')
            ->assertJsonPath('data.quantity', 3);
    }

    public function test_item_update_cannot_move_to_another_list(): void
    {
        $user = $this->actingUser();
        $list = ShoppingList::factory()->create(['owner_id' => $user->id]);
        $otherList = ShoppingList::factory()->create(['owner_id' => $user->id]);
        $item = ShoppingItem::factory()->create(['list_id' => $list->id]);

        $this->patchJson($this->api("/shopping-items/{$item->id}"), ['list_id' => $otherList->id])
            ->assertOk();

        $this->assertSame($list->id, $item->fresh()->list_id);
    }

    public function test_owner_can_delete_item(): void
    {
        $user = $this->actingUser();
        $list = ShoppingList::factory()->create(['owner_id' => $user->id]);
        $item = ShoppingItem::factory()->create(['list_id' => $list->id]);

        $this->deleteJson($this->api("/shopping-items/{$item->id}"))->assertNoContent();
        $this->assertDatabaseMissing('shopping_items', ['id' => $item->id]);
    }

    // ── Security: чужие списки и позиции ────────────────────

    public function test_stranger_cannot_touch_foreign_list_and_items(): void
    {
        $a = User::factory()->create();
        $listA = ShoppingList::factory()->create(['owner_id' => $a->id]);
        $itemA = ShoppingItem::factory()->create(['list_id' => $listA->id]);

        $b = User::factory()->create();
        $listB = ShoppingList::factory()->create(['owner_id' => $b->id]);
        $itemB = ShoppingItem::factory()->create(['list_id' => $listB->id]);

        Sanctum::actingAs($b);

        // Все операции над чужими — 404, существование не раскрываем.
        $this->getJson($this->api("/shopping-lists/{$listA->id}"))->assertNotFound();
        $this->patchJson($this->api("/shopping-lists/{$listA->id}"), ['title' => 'X'])->assertNotFound();
        $this->deleteJson($this->api("/shopping-lists/{$listA->id}"))->assertNotFound();
        $this->postJson($this->api("/shopping-lists/{$listA->id}/items"), ['title' => 'X'])->assertNotFound();
        $this->patchJson($this->api("/shopping-items/{$itemA->id}"), ['is_checked' => true])->assertNotFound();
        $this->deleteJson($this->api("/shopping-items/{$itemA->id}"))->assertNotFound();

        // Свои — работают.
        $this->getJson($this->api("/shopping-lists/{$listB->id}"))->assertOk();
        $this->patchJson($this->api("/shopping-items/{$itemB->id}"), ['is_checked' => true])->assertOk();

        $this->assertDatabaseHas('shopping_lists', ['id' => $listA->id]);
        $this->assertDatabaseHas('shopping_items', ['id' => $itemA->id]);
    }

    // ── Cascade ─────────────────────────────────────────────

    public function test_deleting_user_cascades_lists_and_items(): void
    {
        $user = User::factory()->create();
        $list = ShoppingList::factory()->create(['owner_id' => $user->id]);
        ShoppingItem::factory()->count(2)->create(['list_id' => $list->id]);

        $user->delete();

        $this->assertDatabaseCount('shopping_lists', 0);
        $this->assertDatabaseCount('shopping_items', 0);
    }

    // ── Client-generated UUID (offline-first) ────────────────

    public function test_create_list_accepts_client_uuid(): void
    {
        $this->actingUser();
        $id = fake()->uuid();

        $this->postJson($this->api('/shopping-lists'), [
            'id' => $id,
            'title' => 'Оффлайн список',
        ])->assertCreated()
            ->assertJsonPath('data.id', $id);

        $this->assertDatabaseHas('shopping_lists', ['id' => $id]);
    }

    public function test_create_list_without_id_generates_server_uuid(): void
    {
        $this->actingUser();

        $response = $this->postJson($this->api('/shopping-lists'), ['title' => 'Обычный'])
            ->assertCreated();

        $this->assertSame(1, preg_match('/^[0-9a-f-]{36}$/i', $response->json('data.id')));
    }

    public function test_create_list_rejects_invalid_uuid(): void
    {
        $this->actingUser();

        $this->postJson($this->api('/shopping-lists'), [
            'id' => 'nope',
            'title' => 'X',
        ])->assertUnprocessable()
            ->assertJsonValidationErrorFor('id');
    }

    public function test_create_list_duplicate_uuid_returns_409(): void
    {
        $this->actingUser();
        $id = fake()->uuid();

        $this->postJson($this->api('/shopping-lists'), ['id' => $id, 'title' => 'A'])
            ->assertCreated();

        $this->postJson($this->api('/shopping-lists'), ['id' => $id, 'title' => 'A'])
            ->assertConflict()
            ->assertJsonPath('message', 'Resource already exists.');

        $this->assertSame(1, ShoppingList::where('id', $id)->count());
    }

    public function test_create_list_duplicate_uuid_from_other_user_still_409(): void
    {
        $taken = ShoppingList::factory()->create()->id;
        $this->actingUser();

        $response = $this->postJson($this->api('/shopping-lists'), ['id' => $taken, 'title' => 'X'])
            ->assertConflict()
            ->assertJsonPath('message', 'Resource already exists.');

        $this->assertArrayNotHasKey('data', $response->json());
        $this->assertSame(1, ShoppingList::where('id', $taken)->count());
    }

    public function test_create_item_accepts_client_uuid(): void
    {
        $user = $this->actingUser();
        $list = ShoppingList::factory()->create(['owner_id' => $user->id]);
        $id = fake()->uuid();

        $this->postJson($this->api("/shopping-lists/{$list->id}/items"), [
            'id' => $id,
            'title' => 'Молоко',
        ])->assertCreated()
            ->assertJsonPath('data.id', $id)
            ->assertJsonPath('data.quantity', 1)
            ->assertJsonPath('data.is_checked', false);

        $this->assertDatabaseHas('shopping_items', ['id' => $id, 'list_id' => $list->id]);
    }

    public function test_create_item_without_id_generates_server_uuid(): void
    {
        $user = $this->actingUser();
        $list = ShoppingList::factory()->create(['owner_id' => $user->id]);

        $response = $this->postJson($this->api("/shopping-lists/{$list->id}/items"), ['title' => 'Хлеб'])
            ->assertCreated();

        $this->assertSame(1, preg_match('/^[0-9a-f-]{36}$/i', $response->json('data.id')));
    }

    public function test_create_item_rejects_invalid_uuid(): void
    {
        $user = $this->actingUser();
        $list = ShoppingList::factory()->create(['owner_id' => $user->id]);

        $this->postJson($this->api("/shopping-lists/{$list->id}/items"), [
            'id' => 'bad',
            'title' => 'X',
        ])->assertUnprocessable()
            ->assertJsonValidationErrorFor('id');
    }

    public function test_create_item_duplicate_uuid_returns_409(): void
    {
        $user = $this->actingUser();
        $list = ShoppingList::factory()->create(['owner_id' => $user->id]);
        $id = fake()->uuid();

        $this->postJson($this->api("/shopping-lists/{$list->id}/items"), ['id' => $id, 'title' => 'A'])
            ->assertCreated();

        $this->postJson($this->api("/shopping-lists/{$list->id}/items"), ['id' => $id, 'title' => 'A'])
            ->assertConflict()
            ->assertJsonPath('message', 'Resource already exists.');

        $this->assertSame(1, ShoppingItem::where('id', $id)->count());
        $this->assertSame($list->id, ShoppingItem::find($id)->list_id);
    }

    public function test_create_item_client_uuid_cannot_reach_foreign_list(): void
    {
        // User B с client UUID всё равно не может добавить item в чужой список.
        $foreignList = ShoppingList::factory()->create();
        $this->actingUser();

        $this->postJson($this->api("/shopping-lists/{$foreignList->id}/items"), [
            'id' => fake()->uuid(),
            'title' => 'X',
        ])->assertNotFound();

        $this->assertDatabaseCount('shopping_items', 0);
    }

    public function test_create_item_client_uuid_colliding_with_foreign_item_409(): void
    {
        // Item UUID занят позицией в чужом списке → 409, без утечки.
        $foreignItem = ShoppingItem::factory()->create();
        $user = $this->actingUser();
        $list = ShoppingList::factory()->create(['owner_id' => $user->id]);

        $this->postJson($this->api("/shopping-lists/{$list->id}/items"), [
            'id' => $foreignItem->id,
            'title' => 'X',
        ])->assertConflict()
            ->assertJsonPath('message', 'Resource already exists.');

        $this->assertSame(1, ShoppingItem::where('id', $foreignItem->id)->count());
    }
}
