<?php

namespace Tests\Feature;

use App\Jobs\DeleteMediaClientObjects;
use App\Models\User;
use App\Models\Wish;
use App\Models\WishImage;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Queue;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * Контракт мультифото желания:
 *
 * - `images` — упорядоченный набор ДОПОЛНИТЕЛЬНЫХ изображений
 *   (primary — `image_url`, семантика прежняя);
 * - POST: отсутствие/null = без изображений, массив = набор
 *   (индекс → sort_order);
 * - PATCH: поле отсутствует = не трогать; [] = удалить все;
 *   […] = полная замена набора (по id); null → 422.
 */
class WishImagesApiTest extends TestCase
{
    use RefreshDatabase;

    private function actingUser(): User
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        return $user;
    }

    public function test_wish_without_images_returns_empty_list(): void
    {
        $user = $this->actingUser();
        $wish = Wish::factory()->create(['owner_id' => $user->id]);

        $this->getJson($this->api("/wishes/{$wish->id}"))
            ->assertOk()
            ->assertJsonPath('data.images', []);
    }

    public function test_create_wish_with_images(): void
    {
        $this->actingUser();

        $response = $this->postJson($this->api('/wishes'), [
            'title' => 'Фото желание',
            'image_url' => 'https://cdn.test/primary.jpg',
            'images' => [
                ['url' => 'https://cdn.test/a.jpg'],
                ['url' => 'https://cdn.test/b.jpg'],
            ],
        ])->assertCreated();

        $data = $response->json('data');
        $this->assertSame('https://cdn.test/primary.jpg', $data['image_url']);
        $this->assertCount(2, $data['images']);
        $this->assertSame('https://cdn.test/a.jpg', $data['images'][0]['url']);
        $this->assertSame('https://cdn.test/b.jpg', $data['images'][1]['url']);
        $this->assertSame(1, $data['images'][0]['sort_order']);
        $this->assertSame(2, $data['images'][1]['sort_order']);
        $this->assertNotNull($data['images'][0]['id']);
    }

    public function test_create_wish_accepts_client_image_ids(): void
    {
        $this->actingUser();
        $imageId = fake()->uuid();

        $this->postJson($this->api('/wishes'), [
            'title' => 'X',
            'images' => [['id' => $imageId, 'url' => 'https://cdn.test/a.jpg']],
        ])->assertCreated()
            ->assertJsonPath('data.images.0.id', $imageId);

        $this->assertDatabaseHas('wish_images', ['id' => $imageId]);
    }

    public function test_create_wish_validates_images(): void
    {
        $this->actingUser();

        $this->postJson($this->api('/wishes'), [
            'title' => 'X',
            'images' => [['url' => 'not-a-url']],
        ])->assertUnprocessable()
            ->assertJsonValidationErrors(['images.0.url']);

        $this->postJson($this->api('/wishes'), [
            'title' => 'X',
            'images' => [['id' => 'not-uuid', 'url' => 'https://cdn.test/a.jpg']],
        ])->assertUnprocessable()
            ->assertJsonValidationErrors(['images.0.id']);
    }

    public function test_update_without_images_field_keeps_them(): void
    {
        $user = $this->actingUser();
        $wish = Wish::factory()->create(['owner_id' => $user->id]);
        WishImage::factory()->create(['wish_id' => $wish->id, 'sort_order' => 1]);

        $this->patchJson($this->api("/wishes/{$wish->id}"), [
            'title' => 'Переименовано',
        ])->assertOk()
            ->assertJsonCount(1, 'data.images');

        $this->assertSame(1, $wish->images()->count());
    }

    public function test_update_with_empty_images_clears_them(): void
    {
        $user = $this->actingUser();
        $wish = Wish::factory()->create(['owner_id' => $user->id]);
        WishImage::factory()->count(2)->create(['wish_id' => $wish->id]);

        $this->patchJson($this->api("/wishes/{$wish->id}"), [
            'images' => [],
        ])->assertOk()
            ->assertJsonPath('data.images', []);

        $this->assertSame(0, $wish->images()->count());
    }

    public function test_update_images_null_is_rejected(): void
    {
        $user = $this->actingUser();
        $wish = Wish::factory()->create(['owner_id' => $user->id]);

        $this->patchJson($this->api("/wishes/{$wish->id}"), [
            'images' => null,
        ])->assertUnprocessable();
    }

    public function test_update_images_replaces_set_and_preserves_ids(): void
    {
        Queue::fake();
        $user = $this->actingUser();
        $wish = Wish::factory()->create(['owner_id' => $user->id]);
        $keep = WishImage::factory()->create([
            'wish_id' => $wish->id,
            'url' => 'https://cdn.test/keep.jpg',
            'sort_order' => 1,
        ]);
        $drop = WishImage::factory()->create([
            'wish_id' => $wish->id,
            'sort_order' => 2,
        ]);
        $newId = fake()->uuid();

        $this->patchJson($this->api("/wishes/{$wish->id}"), [
            'images' => [
                // Порядок изменён: new первым, keep вторым.
                ['id' => $newId, 'url' => 'https://cdn.test/new.jpg'],
                ['id' => $keep->id, 'url' => 'https://cdn.test/keep.jpg'],
            ],
        ])->assertOk();

        $images = $wish->images()->get();
        $this->assertSame(2, $images->count());
        $this->assertSame($newId, $images[0]->id);
        $this->assertSame(1, $images[0]->sort_order);
        $this->assertSame($keep->id, $images[1]->id);
        $this->assertSame(2, $images[1]->sort_order);
        $this->assertDatabaseMissing('wish_images', ['id' => $drop->id]);

        // Удалённое изображение → cleanup его media-объекта.
        Queue::assertPushed(
            DeleteMediaClientObjects::class,
            fn ($job) => $job->purpose === 'wish'
                && $job->clientIds === [$drop->id]
                && $job->userId === $user->id,
        );
    }

    public function test_update_images_cannot_hijack_foreign_image_id(): void
    {
        Queue::fake();
        $user = $this->actingUser();
        $other = User::factory()->create();
        $otherWish = Wish::factory()->create(['owner_id' => $other->id]);
        $foreign = WishImage::factory()->create(['wish_id' => $otherWish->id]);

        $wish = Wish::factory()->create(['owner_id' => $user->id]);

        $this->patchJson($this->api("/wishes/{$wish->id}"), [
            'images' => [
                ['id' => $foreign->id, 'url' => 'https://cdn.test/mine.jpg'],
            ],
        ])->assertOk();

        // Чужое изображение не переназначено и не изменено.
        $this->assertSame($otherWish->id, $foreign->fresh()->wish_id);
        // Для wish создана НОВАЯ строка (серверный id, не foreign).
        $image = $wish->images()->sole();
        $this->assertNotSame($foreign->id, $image->id);
        $this->assertSame('https://cdn.test/mine.jpg', $image->url);
    }

    public function test_deleting_wish_cascades_images(): void
    {
        $user = $this->actingUser();
        $wish = Wish::factory()->create(['owner_id' => $user->id]);
        WishImage::factory()->count(2)->create(['wish_id' => $wish->id]);

        $this->deleteJson($this->api("/wishes/{$wish->id}"))->assertNoContent();

        $this->assertDatabaseMissing('wishes', ['id' => $wish->id]);
        $this->assertDatabaseCount('wish_images', 0);
    }

    public function test_friend_wishes_include_images(): void
    {
        $user = $this->actingUser();
        $friend = User::factory()->create();
        \App\Models\Friendship::createBetween($user, $friend);
        $wish = Wish::factory()->create(['owner_id' => $friend->id]);
        WishImage::factory()->create([
            'wish_id' => $wish->id,
            'url' => 'https://cdn.test/friend.jpg',
        ]);

        $response = $this->getJson($this->api("/friends/{$friend->id}/wishes"))
            ->assertOk();

        $this->assertSame(
            'https://cdn.test/friend.jpg',
            $response->json("data.0.images.0.url"),
        );
    }
}
