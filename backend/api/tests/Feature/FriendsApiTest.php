<?php

namespace Tests\Feature;

use App\Models\Friendship;
use App\Models\User;
use App\Models\Wish;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class FriendsApiTest extends TestCase
{
    use RefreshDatabase;

    private function actingUser(): User
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        return $user;
    }

    // ── Search ──────────────────────────────────────────────

    public function test_unauthenticated_cannot_search_users(): void
    {
        $this->getJson($this->api('/users/search?q=alex'))->assertUnauthorized();
    }

    public function test_search_requires_q(): void
    {
        $this->actingUser();

        $this->getJson($this->api('/users/search'))
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['q']);

        $this->getJson($this->api('/users/search?q=@')) // '@' без username
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['q']);
    }

    public function test_search_by_username_and_at_prefix(): void
    {
        $this->actingUser();
        User::factory()->create(['username' => 'alex', 'name' => 'Саша']);
        User::factory()->create(['username' => 'bob', 'name' => 'Боб']);

        $this->getJson($this->api('/users/search?q=alex'))
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.username', 'alex');

        $this->getJson($this->api('/users/search?q=@alex'))
            ->assertOk()
            ->assertJsonPath('data.0.username', 'alex');
    }

    public function test_search_by_name_is_case_insensitive(): void
    {
        $this->actingUser();
        User::factory()->create(['name' => 'Александр Петров', 'username' => 'apetrov']);

        $this->getJson($this->api('/users/search?q=александр'))
            ->assertOk()
            ->assertJsonPath('data.0.username', 'apetrov');

        $this->getJson($this->api('/users/search?q=APETROV'))
            ->assertOk()
            ->assertJsonPath('data.0.username', 'apetrov');
    }

    public function test_search_does_not_expose_email_and_marks_friends(): void
    {
        $me = $this->actingUser();
        $friend = User::factory()->create(['username' => 'alex']);
        User::factory()->create(['username' => 'alexa']);
        Friendship::createBetween($me, $friend);

        $response = $this->getJson($this->api('/users/search?q=alex'))->assertOk();

        foreach ($response->json('data') as $u) {
            $this->assertArrayNotHasKey('email', $u);
        }
        $byUsername = collect($response->json('data'))->keyBy('username');
        $this->assertTrue($byUsername['alex']['is_friend']);
        $this->assertFalse($byUsername['alexa']['is_friend']);
    }

    public function test_search_does_not_return_self_or_wishes(): void
    {
        $me = $this->actingUser();
        $me->update(['username' => 'myself']);

        $response = $this->getJson($this->api('/users/search?q=myself'))->assertOk();
        $this->assertCount(0, $response->json('data'));
    }

    public function test_search_is_limited_to_20(): void
    {
        $this->actingUser();
        User::factory()->count(25)->create(['name' => 'Candidate']);

        $response = $this->getJson($this->api('/users/search?q=candidate'))->assertOk();
        $this->assertCount(20, $response->json('data'));
    }

    // ── Add friend ──────────────────────────────────────────

    public function test_user_can_add_friend(): void
    {
        $me = $this->actingUser();
        $friend = User::factory()->create();

        $this->postJson($this->api('/friends'), ['user_id' => $friend->id])
            ->assertCreated()
            ->assertJsonPath('data.id', $friend->id)
            ->assertJsonPath('data.is_friend', true);

        $this->assertDatabaseCount('friendships', 1);
        $f = Friendship::sole();
        $this->assertSame('accepted', $f->status);
        $this->assertSame($me->id, $f->initiator_id);
        $this->assertTrue($f->involves($me) && $f->involves($friend));
        $this->assertTrue(strcmp($f->user_id, $f->friend_id) < 0); // нормализация
    }

    public function test_cannot_add_self(): void
    {
        $me = $this->actingUser();

        $this->postJson($this->api('/friends'), ['user_id' => $me->id])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['user_id']);
    }

    public function test_cannot_add_nonexistent_user(): void
    {
        $this->actingUser();

        $this->postJson($this->api('/friends'), ['user_id' => fake()->uuid()])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['user_id']);

        $this->postJson($this->api('/friends'), ['user_id' => 'not-a-uuid'])
            ->assertUnprocessable();
    }

    public function test_duplicate_friendship_rejected_in_both_directions(): void
    {
        $a = $this->actingUser();
        $b = User::factory()->create();
        Friendship::createBetween($a, $b);

        // Та же пара повторно.
        $this->postJson($this->api('/friends'), ['user_id' => $b->id])
            ->assertConflict();

        // Обратное направление: B добавляет A — тоже дубликат.
        Sanctum::actingAs($b);
        $this->postJson($this->api('/friends'), ['user_id' => $a->id])
            ->assertConflict();

        $this->assertDatabaseCount('friendships', 1);
    }

    public function test_unauthenticated_cannot_add_friend(): void
    {
        $this->postJson($this->api('/friends'), ['user_id' => fake()->uuid()])
            ->assertUnauthorized();
    }

    // ── Friends list ────────────────────────────────────────

    public function test_friends_list_returns_only_own_friends_sorted_by_name(): void
    {
        $me = $this->actingUser();
        $zeta = User::factory()->create(['name' => 'Zeta']);
        $anna = User::factory()->create(['name' => 'Anna']);
        $noname = User::factory()->create(['name' => null, 'username' => 'noname']);
        User::factory()->create(['name' => 'Chuzhoy']);

        foreach ([$zeta, $anna, $noname] as $u) {
            Friendship::createBetween($me, $u);
        }

        $response = $this->getJson($this->api('/friends'))->assertOk();

        $names = array_column($response->json('data'), 'name');
        $this->assertSame(['Anna', 'Zeta', null], $names); // NULLS LAST
        foreach ($response->json('data') as $f) {
            $this->assertArrayNotHasKey('email', $f);
            $this->assertTrue($f['is_friend']);
        }
    }

    public function test_friends_list_requires_auth(): void
    {
        $this->getJson($this->api('/friends'))->assertUnauthorized();
    }

    // ── Friend profile ──────────────────────────────────────

    public function test_friend_profile_visible_to_friend(): void
    {
        $me = $this->actingUser();
        $friend = User::factory()->create([
            'name' => 'Alex',
            'username' => 'alex',
            'email' => 'alex@example.com',
        ]);
        Friendship::createBetween($me, $friend);

        $this->getJson($this->api("/friends/{$friend->id}"))
            ->assertOk()
            ->assertJsonPath('data.id', $friend->id)
            ->assertJsonPath('data.name', 'Alex')
            ->assertJsonPath('data.username', 'alex');

        $this->assertArrayNotHasKey('email', $this->getJson($this->api("/friends/{$friend->id}"))->json('data'));
    }

    public function test_friend_profile_hidden_from_stranger(): void
    {
        $this->actingUser();
        $other = User::factory()->create();

        // Нет дружбы → 404, существование не раскрываем.
        $this->getJson($this->api("/friends/{$other->id}"))->assertNotFound();
    }

    public function test_friend_profile_404_for_nonexistent_user(): void
    {
        $this->actingUser();

        $this->getJson($this->api('/friends/'.fake()->uuid()))->assertNotFound();
    }

    // ── Friend wishes ───────────────────────────────────────

    public function test_friend_can_view_friend_wishes_sorted_desc(): void
    {
        $me = $this->actingUser();
        $friend = User::factory()->create();
        Friendship::createBetween($me, $friend);

        $old = Wish::factory()->create(['owner_id' => $friend->id, 'title' => 'Старое', 'created_at' => now()->subDay()]);
        $new = Wish::factory()->create(['owner_id' => $friend->id, 'title' => 'Новое']);

        $response = $this->getJson($this->api("/friends/{$friend->id}/wishes"))->assertOk();

        $this->assertSame($new->id, $response->json('data.0.id'));
        $this->assertSame($old->id, $response->json('data.1.id'));
    }

    public function test_owner_can_view_own_wishes_via_friend_endpoint(): void
    {
        $me = $this->actingUser();
        Wish::factory()->create(['owner_id' => $me->id]);

        $this->getJson($this->api("/friends/{$me->id}/wishes"))
            ->assertOk()
            ->assertJsonCount(1, 'data');
    }

    public function test_stranger_cannot_view_friend_wishes(): void
    {
        $this->actingUser();
        $owner = User::factory()->create();
        Wish::factory()->create(['owner_id' => $owner->id]);

        $this->getJson($this->api("/friends/{$owner->id}/wishes"))->assertNotFound();
    }

    public function test_friend_can_view_single_wish_of_friend(): void
    {
        $me = $this->actingUser();
        $friend = User::factory()->create();
        Friendship::createBetween($me, $friend);
        $wish = Wish::factory()->create(['owner_id' => $friend->id]);

        // Чтение — ок (WishPolicy::view), изменение — нет.
        $this->getJson($this->api("/wishes/{$wish->id}"))->assertOk();
        $this->patchJson($this->api("/wishes/{$wish->id}"), ['title' => 'X'])->assertNotFound();
        $this->deleteJson($this->api("/wishes/{$wish->id}"))->assertNotFound();
    }

    // ── Delete friendship ───────────────────────────────────

    public function test_friend_can_delete_friendship_symmetrically(): void
    {
        $me = $this->actingUser();
        $friend = User::factory()->create();
        Friendship::createBetween($me, $friend);

        $this->deleteJson($this->api("/friends/{$friend->id}"))->assertNoContent();
        $this->assertDatabaseCount('friendships', 0);

        // Обратной записи тоже нет; профиль и wishes снова закрыты.
        $this->getJson($this->api("/friends/{$friend->id}"))->assertNotFound();
        $this->getJson($this->api("/friends/{$friend->id}/wishes"))->assertNotFound();
    }

    public function test_delete_nonexistent_friendship_is_404(): void
    {
        $this->actingUser();
        $other = User::factory()->create();

        $this->deleteJson($this->api("/friends/{$other->id}"))->assertNotFound();
    }

    public function test_delete_friendship_keeps_user_and_wishes(): void
    {
        $me = $this->actingUser();
        $friend = User::factory()->create();
        $wish = Wish::factory()->create(['owner_id' => $friend->id]);
        Friendship::createBetween($me, $friend);

        $this->deleteJson($this->api("/friends/{$friend->id}"))->assertNoContent();

        $this->assertDatabaseHas('users', ['id' => $friend->id]);
        $this->assertDatabaseHas('wishes', ['id' => $wish->id]);
    }

    // ── Security: третий пользователь ───────────────────────

    public function test_third_user_cannot_touch_foreign_friendship(): void
    {
        $a = User::factory()->create();
        $b = User::factory()->create();
        $c = User::factory()->create();
        Friendship::createBetween($a, $b);
        $wishA = Wish::factory()->create(['owner_id' => $a->id]);

        Sanctum::actingAs($c);

        $this->getJson($this->api("/friends/{$a->id}"))->assertNotFound();
        $this->getJson($this->api("/friends/{$a->id}/wishes"))->assertNotFound();
        $this->getJson($this->api("/wishes/{$wishA->id}"))->assertNotFound();

        // C не может удалить дружбу A↔B (своей пары с A нет).
        $this->deleteJson($this->api("/friends/{$a->id}"))->assertNotFound();
        $this->assertDatabaseCount('friendships', 1);
        $this->assertDatabaseHas('wishes', ['id' => $wishA->id]);
    }
}
