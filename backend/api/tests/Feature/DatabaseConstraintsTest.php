<?php

namespace Tests\Feature;

use App\Models\Friendship;
use App\Models\ShoppingList;
use App\Models\User;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/**
 * Проверка ограничений на уровне PostgreSQL:
 * unique, check-констрейнты, внешние ключи.
 */
class DatabaseConstraintsTest extends TestCase
{
    use RefreshDatabase;

    public function test_users_email_unique_at_database_level(): void
    {
        User::factory()->create(['email' => 'dup@example.com']);

        $this->expectException(QueryException::class);
        User::factory()->create(['email' => 'dup@example.com']);
    }

    public function test_users_username_unique_at_database_level(): void
    {
        User::factory()->create(['username' => 'uniq']);

        $this->expectException(QueryException::class);
        User::factory()->create(['username' => 'uniq']);
    }

    public function test_users_username_format_check_at_database_level(): void
    {
        $this->expectException(QueryException::class);

        // Обходим модельную валидацию — прямой INSERT.
        DB::table('users')->insert([
            'id' => fake()->uuid(),
            'username' => 'BAD-NAME!',
            'email' => 'bad@example.com',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    public function test_wishes_price_must_be_non_negative_at_database_level(): void
    {
        $user = User::factory()->create();

        $this->expectException(QueryException::class);

        DB::table('wishes')->insert([
            'id' => fake()->uuid(),
            'owner_id' => $user->id,
            'title' => 'Тест',
            'price' => -1,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    public function test_wishes_owner_fk_enforced(): void
    {
        $this->expectException(QueryException::class);

        DB::table('wishes')->insert([
            'id' => fake()->uuid(),
            'owner_id' => fake()->uuid(), // пользователя не существует
            'title' => 'Тест',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    public function test_owner_id_created_at_index_exists(): void
    {
        $indexes = DB::select(
            "SELECT indexname FROM pg_indexes WHERE tablename = 'wishes'"
        );

        $names = array_column($indexes, 'indexname');
        $this->assertContains('wishes_owner_id_created_at_index', $names);
    }

    // ── friendships ─────────────────────────────────────────

    private function insertFriendship(string $a, string $b, string $initiator): void
    {
        DB::table('friendships')->insert([
            'id' => fake()->uuid(),
            'user_id' => $a,
            'friend_id' => $b,
            'initiator_id' => $initiator,
            'status' => 'accepted',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    public function test_friendship_unique_pair_at_database_level(): void
    {
        [$a, $b] = [User::factory()->create(), User::factory()->create()];
        [$lo, $hi] = Friendship::normalizePair($a->id, $b->id);
        $this->insertFriendship($lo, $hi, $a->id);

        $this->expectException(QueryException::class);
        $this->insertFriendship($lo, $hi, $b->id); // та же пара
    }

    public function test_friendship_rejects_self_pair(): void
    {
        $a = User::factory()->create();

        $this->expectException(QueryException::class);
        $this->insertFriendship($a->id, $a->id, $a->id);
    }

    public function test_friendship_rejects_unnormalized_pair(): void
    {
        [$a, $b] = [User::factory()->create(), User::factory()->create()];
        [$lo, $hi] = Friendship::normalizePair($a->id, $b->id);

        // Обратный порядок запрещён CHECK-констрейнтом user_id < friend_id.
        $this->expectException(QueryException::class);
        $this->insertFriendship($hi, $lo, $a->id);
    }

    public function test_friendship_fk_enforced(): void
    {
        $a = User::factory()->create();

        $this->expectException(QueryException::class);
        $this->insertFriendship($a->id, fake()->uuid(), $a->id);
    }

    public function test_deleting_user_cascades_friendships_both_sides(): void
    {
        [$a, $b, $c] = [
            User::factory()->create(),
            User::factory()->create(),
            User::factory()->create(),
        ];
        Friendship::createBetween($a, $b); // a или b в user_id — неважно
        Friendship::createBetween($b, $c);

        $b->delete();

        $this->assertDatabaseCount('friendships', 0);
        $this->assertDatabaseHas('users', ['id' => $a->id]);
        $this->assertDatabaseHas('users', ['id' => $c->id]);
    }

    // ── shopping ────────────────────────────────────────────

    public function test_shopping_items_quantity_must_be_positive(): void
    {
        $user = User::factory()->create();
        $list = ShoppingList::factory()->create(['owner_id' => $user->id]);

        $this->expectException(QueryException::class);
        DB::table('shopping_items')->insert([
            'id' => fake()->uuid(),
            'list_id' => $list->id,
            'title' => 'Тест',
            'quantity' => 0,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    public function test_shopping_items_fk_enforced(): void
    {
        $this->expectException(QueryException::class);
        DB::table('shopping_items')->insert([
            'id' => fake()->uuid(),
            'list_id' => fake()->uuid(),
            'title' => 'Тест',
            'quantity' => 1,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }
}
