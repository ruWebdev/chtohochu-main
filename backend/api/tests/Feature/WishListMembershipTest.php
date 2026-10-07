<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\Wish;
use App\Models\WishList;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * Membership Wish → WishList: `wishes.list_id` часть API-
 * контракта желания. null = вне списков; список и желание
 * должны принадлежать одному пользователю.
 */
class WishListMembershipTest extends TestCase
{
    use RefreshDatabase;

    private function actingUser(): User
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        return $user;
    }

    public function test_wish_list_id_defaults_to_null(): void
    {
        $this->actingUser();

        $this->postJson($this->api('/wishes'), ['title' => 'Соло'])
            ->assertCreated()
            ->assertJsonPath('data.list_id', null);

        $this->assertNull(Wish::sole()->list_id);
    }

    public function test_create_wish_with_own_list(): void
    {
        $user = $this->actingUser();
        $list = WishList::factory()->create(['owner_id' => $user->id]);

        $this->postJson($this->api('/wishes'), [
            'title' => 'Носки',
            'list_id' => $list->id,
        ])->assertCreated()
            ->assertJsonPath('data.list_id', $list->id);

        $this->assertSame($list->id, Wish::sole()->list_id);
    }

    public function test_update_membership_all_transitions(): void
    {
        $user = $this->actingUser();
        $a = WishList::factory()->create(['owner_id' => $user->id]);
        $b = WishList::factory()->create(['owner_id' => $user->id]);
        $wish = Wish::factory()->create(['owner_id' => $user->id]);

        // null → A
        $this->patchJson($this->api("/wishes/{$wish->id}"), ['list_id' => $a->id])
            ->assertOk()->assertJsonPath('data.list_id', $a->id);

        // A → B
        $this->patchJson($this->api("/wishes/{$wish->id}"), ['list_id' => $b->id])
            ->assertOk()->assertJsonPath('data.list_id', $b->id);

        // B → null
        $this->patchJson($this->api("/wishes/{$wish->id}"), ['list_id' => null])
            ->assertOk()->assertJsonPath('data.list_id', null);
    }

    public function test_cannot_assign_foreign_list(): void
    {
        $user = $this->actingUser();
        $foreign = WishList::factory()->create(); // другого owner'а
        $wish = Wish::factory()->create(['owner_id' => $user->id]);

        // Чужой список не раскрывается — обычная валидация 422.
        $this->postJson($this->api('/wishes'), [
            'title' => 'X',
            'list_id' => $foreign->id,
        ])->assertUnprocessable()->assertJsonValidationErrors(['list_id']);

        $this->patchJson($this->api("/wishes/{$wish->id}"), [
            'list_id' => $foreign->id,
        ])->assertUnprocessable()->assertJsonValidationErrors(['list_id']);

        $this->assertNull($wish->fresh()->list_id);
    }

    public function test_cannot_assign_soft_deleted_list(): void
    {
        $user = $this->actingUser();
        $list = WishList::factory()->create(['owner_id' => $user->id]);
        $list->delete();

        $this->patchJson(
            $this->api('/wishes/'.Wish::factory()->create(['owner_id' => $user->id])->id),
            ['list_id' => $list->id],
        )->assertUnprocessable();
    }

    public function test_index_returns_list_id(): void
    {
        $user = $this->actingUser();
        $list = WishList::factory()->create(['owner_id' => $user->id]);
        Wish::factory()->create(['owner_id' => $user->id, 'list_id' => $list->id]);
        Wish::factory()->create(['owner_id' => $user->id]);

        $response = $this->getJson($this->api('/wishes'))->assertOk();

        $this->assertCount(2, $response->json('data'));
        $this->assertArrayHasKey('list_id', $response->json('data.0'));
    }

    public function test_deleting_list_ungroups_its_wishes(): void
    {
        $user = $this->actingUser();
        $list = WishList::factory()->create(['owner_id' => $user->id]);
        $wish = Wish::factory()->create(['owner_id' => $user->id, 'list_id' => $list->id]);

        $this->deleteJson($this->api("/wish-lists/{$list->id}"))->assertNoContent();

        // Желание живо, связь снята.
        $this->assertNull($wish->fresh()->list_id);
        $this->assertSame(1, Wish::count());
    }

    public function test_deleting_wish_keeps_list(): void
    {
        $user = $this->actingUser();
        $list = WishList::factory()->create(['owner_id' => $user->id]);
        $wish = Wish::factory()->create(['owner_id' => $user->id, 'list_id' => $list->id]);

        $this->deleteJson($this->api("/wishes/{$wish->id}"))->assertNoContent();

        $this->assertSame(1, WishList::count());
    }
}
