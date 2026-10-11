<?php

namespace Tests\Feature;

use App\Events\ShoppingListEvent;
use App\Models\Friendship;
use App\Models\ShoppingItem;
use App\Models\ShoppingList;
use App\Models\User;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * Совместные списки покупок: membership, права owner/member,
 * friend-only добавление, realtime-события, channel auth.
 */
class ShoppingListCollaborationTest extends TestCase
{
    use RefreshDatabase;

    private function actingUser(): User
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        return $user;
    }

    private function friends(User $a, User $b): void
    {
        Friendship::createBetween($a, $b);
    }

    private function addMember(User $owner, ShoppingList $list, User $member): void
    {
        Sanctum::actingAs($owner);
        $this->postJson($this->api("/shopping-lists/{$list->id}/members"), [
            'user_id' => $member->id,
        ])->assertCreated();
    }

    // ── Membership ──────────────────────────────────────────

    public function test_owner_can_add_friend_as_member(): void
    {
        $owner = $this->actingUser();
        $friend = User::factory()->create();
        $this->friends($owner, $friend);
        $list = ShoppingList::factory()->create(['owner_id' => $owner->id]);

        $this->postJson($this->api("/shopping-lists/{$list->id}/members"), [
            'user_id' => $friend->id,
        ])->assertCreated()->assertJsonPath('data.id', $friend->id);

        $this->assertDatabaseHas('shopping_list_members', [
            'list_id' => $list->id,
            'user_id' => $friend->id,
        ]);
    }

    public function test_add_member_requires_friendship(): void
    {
        $owner = $this->actingUser();
        $stranger = User::factory()->create();
        $list = ShoppingList::factory()->create(['owner_id' => $owner->id]);

        $this->postJson($this->api("/shopping-lists/{$list->id}/members"), [
            'user_id' => $stranger->id,
        ])->assertUnprocessable();

        $this->assertDatabaseMissing('shopping_list_members', [
            'list_id' => $list->id,
            'user_id' => $stranger->id,
        ]);
    }

    public function test_add_member_rejects_unknown_and_owner(): void
    {
        $owner = $this->actingUser();
        $list = ShoppingList::factory()->create(['owner_id' => $owner->id]);

        $this->postJson($this->api("/shopping-lists/{$list->id}/members"), [
            'user_id' => fake()->uuid(),
        ])->assertUnprocessable();

        $this->postJson($this->api("/shopping-lists/{$list->id}/members"), [
            'user_id' => $owner->id,
        ])->assertUnprocessable();
    }

    public function test_add_member_is_idempotent(): void
    {
        $owner = $this->actingUser();
        $friend = User::factory()->create();
        $this->friends($owner, $friend);
        $list = ShoppingList::factory()->create(['owner_id' => $owner->id]);

        $this->postJson($this->api("/shopping-lists/{$list->id}/members"), [
            'user_id' => $friend->id,
        ])->assertCreated();
        $this->postJson($this->api("/shopping-lists/{$list->id}/members"), [
            'user_id' => $friend->id,
        ])->assertOk();

        $this->assertDatabaseCount('shopping_list_members', 1);
    }

    public function test_member_cannot_add_members(): void
    {
        $owner = $this->actingUser();
        $member = User::factory()->create();
        $third = User::factory()->create();
        $this->friends($owner, $member);
        $this->friends($member, $third);
        $list = ShoppingList::factory()->create(['owner_id' => $owner->id]);
        $this->addMember($owner, $list, $member);

        Sanctum::actingAs($member);
        $this->postJson($this->api("/shopping-lists/{$list->id}/members"), [
            'user_id' => $third->id,
        ])->assertNotFound();
    }

    public function test_members_index_lists_owner_and_members(): void
    {
        $owner = $this->actingUser();
        $member = User::factory()->create();
        $this->friends($owner, $member);
        $list = ShoppingList::factory()->create(['owner_id' => $owner->id]);
        $this->addMember($owner, $list, $member);

        Sanctum::actingAs($member);
        $response = $this->getJson(
            $this->api("/shopping-lists/{$list->id}/members")
        )->assertOk();

        $ids = collect($response->json('data'))->pluck('id');
        $this->assertContains($owner->id, $ids);
        $this->assertContains($member->id, $ids);
        $this->assertCount(2, $ids);
    }

    // ── Member access ───────────────────────────────────────

    public function test_member_sees_shared_list_in_index(): void
    {
        $owner = $this->actingUser();
        $member = User::factory()->create();
        $this->friends($owner, $member);
        $list = ShoppingList::factory()->create(['owner_id' => $owner->id]);
        $item = ShoppingItem::factory()->create(['list_id' => $list->id]);
        $this->addMember($owner, $list, $member);

        Sanctum::actingAs($member);
        $response = $this->getJson($this->api('/shopping-lists'))->assertOk();
        $ids = collect($response->json('data'))->pluck('id');
        $this->assertContains($list->id, $ids);
        $this->assertCount(1, $ids);

        $this->getJson($this->api("/shopping-lists/{$list->id}"))
            ->assertOk()
            ->assertJsonPath('data.id', $list->id)
            ->assertJsonPath('data.owner_id', $owner->id);
        $this->assertSame($item->id, $this->getJson(
            $this->api("/shopping-lists/{$list->id}")
        )->json('data.items.0.id'));
    }

    public function test_member_can_create_update_toggle_delete_items(): void
    {
        $owner = $this->actingUser();
        $member = User::factory()->create();
        $this->friends($owner, $member);
        $list = ShoppingList::factory()->create(['owner_id' => $owner->id]);
        $this->addMember($owner, $list, $member);

        Sanctum::actingAs($member);
        $itemId = fake()->uuid();
        $this->postJson($this->api("/shopping-lists/{$list->id}/items"), [
            'id' => $itemId,
            'title' => 'Молоко',
        ])->assertCreated();

        // Отметка «куплено» — is_checked через обычный update.
        $this->patchJson($this->api("/shopping-items/{$itemId}"), [
            'is_checked' => true,
        ])->assertOk()->assertJsonPath('data.is_checked', true);

        $this->patchJson($this->api("/shopping-items/{$itemId}"), [
            'title' => 'Кефир',
            'is_checked' => false,
        ])->assertOk()
            ->assertJsonPath('data.title', 'Кефир')
            ->assertJsonPath('data.is_checked', false);

        $this->deleteJson($this->api("/shopping-items/{$itemId}"))
            ->assertNoContent();
        $this->assertDatabaseMissing('shopping_items', ['id' => $itemId]);
    }

    public function test_member_cannot_rename_or_delete_list(): void
    {
        $owner = $this->actingUser();
        $member = User::factory()->create();
        $this->friends($owner, $member);
        $list = ShoppingList::factory()->create(['owner_id' => $owner->id]);
        $this->addMember($owner, $list, $member);

        Sanctum::actingAs($member);
        $this->patchJson($this->api("/shopping-lists/{$list->id}"), [
            'title' => 'Подмена',
        ])->assertNotFound();
        $this->deleteJson($this->api("/shopping-lists/{$list->id}"))
            ->assertNotFound();
        $this->assertDatabaseHas('shopping_lists', ['id' => $list->id]);
    }

    public function test_member_can_leave_list(): void
    {
        $owner = $this->actingUser();
        $member = User::factory()->create();
        $this->friends($owner, $member);
        $list = ShoppingList::factory()->create(['owner_id' => $owner->id]);
        $this->addMember($owner, $list, $member);

        Sanctum::actingAs($member);
        $this->deleteJson(
            $this->api("/shopping-lists/{$list->id}/members/{$member->id}")
        )->assertNoContent();

        // Доступ потерян сразу.
        $this->getJson($this->api("/shopping-lists/{$list->id}"))->assertNotFound();
        $this->assertDatabaseMissing('shopping_list_members', [
            'list_id' => $list->id,
            'user_id' => $member->id,
        ]);
    }

    public function test_owner_can_remove_member(): void
    {
        $owner = $this->actingUser();
        $member = User::factory()->create();
        $this->friends($owner, $member);
        $list = ShoppingList::factory()->create(['owner_id' => $owner->id]);
        $this->addMember($owner, $list, $member);

        Sanctum::actingAs($owner);
        $this->deleteJson(
            $this->api("/shopping-lists/{$list->id}/members/{$member->id}")
        )->assertNoContent();

        Sanctum::actingAs($member);
        $this->getJson($this->api("/shopping-lists/{$list->id}"))->assertNotFound();
    }

    public function test_owner_cannot_be_removed_as_member(): void
    {
        $owner = $this->actingUser();
        $list = ShoppingList::factory()->create(['owner_id' => $owner->id]);

        $this->deleteJson(
            $this->api("/shopping-lists/{$list->id}/members/{$owner->id}")
        )->assertNotFound();
    }

    // ── Unauthorized ────────────────────────────────────────

    public function test_stranger_has_no_access(): void
    {
        $owner = $this->actingUser();
        $stranger = User::factory()->create();
        $list = ShoppingList::factory()->create(['owner_id' => $owner->id]);
        $item = ShoppingItem::factory()->create(['list_id' => $list->id]);

        Sanctum::actingAs($stranger);
        $this->getJson($this->api("/shopping-lists/{$list->id}"))->assertNotFound();
        $this->getJson($this->api("/shopping-lists/{$list->id}/members"))->assertNotFound();
        $this->postJson($this->api("/shopping-lists/{$list->id}/items"), ['title' => 'X'])
            ->assertNotFound();
        $this->patchJson($this->api("/shopping-items/{$item->id}"), ['is_checked' => true])
            ->assertNotFound();
        $this->deleteJson($this->api("/shopping-items/{$item->id}"))->assertNotFound();
        $this->postJson($this->api("/shopping-lists/{$list->id}/members"), [
            'user_id' => $stranger->id,
        ])->assertNotFound();
    }

    public function test_member_cannot_remove_other_member(): void
    {
        $owner = $this->actingUser();
        $m1 = User::factory()->create();
        $m2 = User::factory()->create();
        $this->friends($owner, $m1);
        $this->friends($owner, $m2);
        $list = ShoppingList::factory()->create(['owner_id' => $owner->id]);
        $this->addMember($owner, $list, $m1);
        $this->addMember($owner, $list, $m2);

        Sanctum::actingAs($m1);
        $this->deleteJson(
            $this->api("/shopping-lists/{$list->id}/members/{$m2->id}")
        )->assertNotFound();
    }

    public function test_delete_list_cascades_members(): void
    {
        $owner = $this->actingUser();
        $member = User::factory()->create();
        $this->friends($owner, $member);
        $list = ShoppingList::factory()->create(['owner_id' => $owner->id]);
        $this->addMember($owner, $list, $member);

        Sanctum::actingAs($owner);
        $this->deleteJson($this->api("/shopping-lists/{$list->id}"))->assertNoContent();
        $this->assertDatabaseCount('shopping_list_members', 0);
    }

    // ── Events ──────────────────────────────────────────────

    public function test_item_mutation_broadcasts_event(): void
    {
        Event::fake([ShoppingListEvent::class]);
        $owner = $this->actingUser();
        $member = User::factory()->create();
        $this->friends($owner, $member);
        $list = ShoppingList::factory()->create(['owner_id' => $owner->id]);
        $this->addMember($owner, $list, $member);

        Sanctum::actingAs($member);
        $itemId = fake()->uuid();
        $this->postJson($this->api("/shopping-lists/{$list->id}/items"), [
            'id' => $itemId,
            'title' => 'Молоко',
        ])->assertCreated();

        Event::assertDispatched(
            ShoppingListEvent::class,
            fn ($e) => $e->eventType === 'shopping_list.item.created'
                && $e->entityId === $itemId
                && $e->actorId === $member->id
                && $e->broadcastWith()['payload']['is_checked'] === false
                && collect($e->broadcastOn())->contains(
                    fn ($c) => $c instanceof PrivateChannel
                        && $c->name === "private-shopping-list.{$list->id}"
                )
                && collect($e->broadcastOn())->contains(
                    fn ($c) => $c instanceof PrivateChannel
                        && $c->name === "private-user.{$owner->id}"
                )
        );

        // Toggle → checked event.
        $this->patchJson($this->api("/shopping-items/{$itemId}"), ['is_checked' => true]);
        Event::assertDispatched(
            ShoppingListEvent::class,
            fn ($e) => $e->eventType === 'shopping_list.item.checked'
                && $e->entityId === $itemId
        );
    }

    public function test_member_joined_and_left_events(): void
    {
        Event::fake([ShoppingListEvent::class]);
        $owner = $this->actingUser();
        $member = User::factory()->create();
        $this->friends($owner, $member);
        $list = ShoppingList::factory()->create(['owner_id' => $owner->id]);

        $this->postJson($this->api("/shopping-lists/{$list->id}/members"), [
            'user_id' => $member->id,
        ])->assertCreated();

        // Событие доходит и новому участнику (private-user.{member}).
        Event::assertDispatched(
            ShoppingListEvent::class,
            fn ($e) => $e->eventType === 'shopping_list.participant.joined'
                && collect($e->broadcastOn())->contains(
                    fn ($c) => $c->name === "private-user.{$member->id}"
                )
        );

        $this->deleteJson(
            $this->api("/shopping-lists/{$list->id}/members/{$member->id}")
        )->assertNoContent();

        // Удалённый участник тоже получает событие — его клиент
        // вычистит список при reconcile.
        Event::assertDispatched(
            ShoppingListEvent::class,
            fn ($e) => $e->eventType === 'shopping_list.participant.left'
                && $e->payload['user_id'] === $member->id
                && collect($e->broadcastOn())->contains(
                    fn ($c) => $c->name === "private-user.{$member->id}"
                )
        );
    }

    public function test_list_deleted_event_reaches_members(): void
    {
        Event::fake([ShoppingListEvent::class]);
        $owner = $this->actingUser();
        $member = User::factory()->create();
        $this->friends($owner, $member);
        $list = ShoppingList::factory()->create(['owner_id' => $owner->id]);
        $this->addMember($owner, $list, $member);

        Sanctum::actingAs($owner);
        $this->deleteJson($this->api("/shopping-lists/{$list->id}"))->assertNoContent();

        Event::assertDispatched(
            ShoppingListEvent::class,
            fn ($e) => $e->eventType === 'shopping_list.deleted'
                && collect($e->broadcastOn())->contains(
                    fn ($c) => $c->name === "private-user.{$member->id}"
                )
        );
    }

    // ── Private channel authorization ───────────────────────

    public function test_shopping_list_channel_authorized_for_members_only(): void
    {
        // Каналы регистрируются при boot (см. BroadcastAuthTest):
        // после переключения на reverb файл подключаем повторно.
        config(['broadcasting.default' => 'reverb']);
        require base_path('routes/channels.php');
        $owner = $this->actingUser();
        $member = User::factory()->create();
        $stranger = User::factory()->create();
        $list = ShoppingList::factory()->create(['owner_id' => $owner->id]);
        // Attach напрямую — HTTP-addMember диспатчит событие, а
        // при reverb-default sync-queue реально стучится в Reverb.
        $list->members()->attach($member->id);

        $channel = "private-shopping-list.{$list->id}";
        $socket = '1000.1000';

        // Владелец и участник — 200.
        foreach ([$owner, $member] as $user) {
            Sanctum::actingAs($user);
            $this->postJson($this->api('/broadcasting/auth'), [
                'socket_id' => $socket,
                'channel_name' => $channel,
            ])->assertOk();
        }

        // Чужой — 403.
        Sanctum::actingAs($stranger);
        $this->postJson($this->api('/broadcasting/auth'), [
            'socket_id' => $socket,
            'channel_name' => $channel,
        ])->assertForbidden();

        // Удалённый участник теряет доступ к каналу.
        $list->members()->detach($member->id);
        Sanctum::actingAs($member);
        $this->postJson($this->api('/broadcasting/auth'), [
            'socket_id' => $socket,
            'channel_name' => $channel,
        ])->assertForbidden();
    }

    // ── Concurrency (last-write-wins) ───────────────────────

    public function test_concurrent_is_checked_updates_last_write_wins(): void
    {
        $owner = $this->actingUser();
        $member = User::factory()->create();
        $this->friends($owner, $member);
        $list = ShoppingList::factory()->create(['owner_id' => $owner->id]);
        $item = ShoppingItem::factory()->create([
            'list_id' => $list->id,
            'is_checked' => false,
        ]);
        $this->addMember($owner, $list, $member);

        // A и B меняют одну позицию — последний записавший побеждает,
        // оба запроса успешны (нет optimistic-locking 409).
        Sanctum::actingAs($owner);
        $this->patchJson($this->api("/shopping-items/{$item->id}"), [
            'is_checked' => true,
        ])->assertOk();
        Sanctum::actingAs($member);
        $this->patchJson($this->api("/shopping-items/{$item->id}"), [
            'is_checked' => false,
        ])->assertOk();

        $this->assertFalse($item->fresh()->is_checked);
        // Ревизия монотонно растёт по каждой мутации.
        $this->assertGreaterThanOrEqual(2, $item->fresh()->revision);
    }
}
