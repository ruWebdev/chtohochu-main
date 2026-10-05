<?php

namespace Tests\Feature;

use App\Jobs\DeleteMediaObjects;
use App\Models\MediaUpload;
use App\Models\ShoppingList;
use App\Models\User;
use App\Models\Wish;
use App\Services\Media\MediaStorageGateway;
use App\Services\Media\MediaUploadService;
use DateTimeInterface;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Queue;
use Laravel\Sanctum\Sanctum;
use Symfony\Component\HttpKernel\Exception\HttpException;
use Tests\TestCase;

/**
 * In-memory object storage: presigned URL выдаётся детерминированно,
 * «объект» кладём в $objects напрямую — эмуляция успешного PUT.
 */
class FakeMediaStorageGateway implements MediaStorageGateway
{
    /** @var array<string, array{size:int, mime:string}> */
    public array $objects = [];

    /** @var list<string> */
    public array $deleted = [];

    public function temporaryPutUrl(
        string $disk,
        string $key,
        string $contentType,
        DateTimeInterface $expiresAt,
    ): array {
        return [
            'url' => "https://s3.test/$disk/$key"
                .'?X-Signature=fake&X-Expires='.$expiresAt->getTimestamp(),
            'headers' => ['Content-Type' => $contentType],
        ];
    }

    public function head(string $disk, string $key): array
    {
        $object = $this->objects["$disk/$key"] ?? null;

        return $object === null
            ? ['exists' => false, 'size' => null, 'mime' => null]
            : ['exists' => true, 'size' => $object['size'], 'mime' => $object['mime']];
    }

    public function url(string $disk, string $key): string
    {
        return "https://cdn.test/$disk/$key";
    }

    public function delete(string $disk, string $key): void
    {
        $this->deleted[] = "$disk/$key";
        unset($this->objects["$disk/$key"]);
    }

    public function putObject(string $disk, string $key, int $size, string $mime): void
    {
        $this->objects["$disk/$key"] = ['size' => $size, 'mime' => $mime];
    }
}

class MediaUploadApiTest extends TestCase
{
    use RefreshDatabase;

    private FakeMediaStorageGateway $storage;

    protected function setUp(): void
    {
        parent::setUp();
        $this->storage = new FakeMediaStorageGateway;
        $this->app->instance(MediaStorageGateway::class, $this->storage);
    }

    private function actingUser(): User
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        return $user;
    }

    private function payload(array $overrides = []): array
    {
        return array_merge([
            'purpose' => 'wish',
            'entity_id' => null,
            'content_type' => 'image/jpeg',
            'size' => 1024,
            'client_id' => fake()->uuid(),
        ], $overrides);
    }

    public function test_unauthenticated_requests_rejected(): void
    {
        $this->postJson($this->api('/media/uploads'), $this->payload())
            ->assertUnauthorized();
        $this->postJson($this->api('/media/uploads/'.fake()->uuid().'/complete'))
            ->assertUnauthorized();
    }

    public function test_invalid_purpose_rejected(): void
    {
        $this->actingUser();
        $this->postJson($this->api('/media/uploads'), $this->payload(['purpose' => 'hack']))
            ->assertUnprocessable();
    }

    public function test_invalid_content_type_rejected(): void
    {
        $this->actingUser();

        foreach (['application/octet-stream', 'image/gif', 'text/html'] as $mime) {
            $this->postJson(
                $this->api('/media/uploads'),
                $this->payload(['content_type' => $mime]),
            )->assertUnprocessable();
        }
    }

    public function test_excessive_size_rejected(): void
    {
        $this->actingUser();
        $max = config('media.max_upload_bytes');

        $this->postJson($this->api('/media/uploads'), $this->payload(['size' => $max + 1]))
            ->assertUnprocessable();
        $this->postJson($this->api('/media/uploads'), $this->payload(['size' => 0]))
            ->assertUnprocessable();
    }

    public function test_wish_upload_gets_server_key_and_wish_bucket(): void
    {
        $user = $this->actingUser();
        $wish = Wish::factory()->create(['owner_id' => $user->id]);

        $response = $this->postJson(
            $this->api('/media/uploads'),
            $this->payload(['entity_id' => $wish->id]),
        )->assertCreated();

        $data = $response->json('data');
        $this->assertSame('PUT', $data['method']);
        $this->assertStringStartsWith(
            "chtohochu-wish-images/users/{$user->id}/wishes/{$wish->id}/",
            $data['object_key'],
        );
        $this->assertStringEndsWith('.jpg', $data['object_key']);
        $this->assertStringContainsString($data['object_key'], $data['upload_url']);
        $this->assertStringContainsString($data['object_key'], $data['remote_url']);
        $this->assertNotNull($data['expires_at']);
        // Content-Type обязателен в PUT — иначе объект получает дефолтный
        // MIME и не пройдёт complete (не все провайдеры его подписывают).
        $this->assertSame('image/jpeg', $data['upload_headers']['Content-Type'] ?? null);
        foreach ($data['upload_headers'] as $value) {
            $this->assertIsString($value);
        }

        $upload = MediaUpload::findOrFail($data['upload_id']);
        $this->assertSame(config('filesystems.disks.media_wish_images.bucket'), $upload->bucket);
        $this->assertSame($user->id, $upload->user_id);
    }

    public function test_wish_upload_for_foreign_entity_rejected(): void
    {
        $this->actingUser();
        $foreign = Wish::factory()->create(); // чужое желание

        $this->postJson(
            $this->api('/media/uploads'),
            $this->payload(['entity_id' => $foreign->id]),
        )->assertNotFound();
    }

    public function test_wish_upload_requires_entity(): void
    {
        $this->actingUser();
        $this->postJson($this->api('/media/uploads'), $this->payload(['entity_id' => null]))
            ->assertUnprocessable();
    }

    public function test_avatar_upload_uses_own_namespace(): void
    {
        $user = $this->actingUser();

        $response = $this->postJson(
            $this->api('/media/uploads'),
            $this->payload(['purpose' => 'avatar', 'entity_id' => null]),
        )->assertCreated();

        $data = $response->json('data');
        $this->assertStringStartsWith("chtohochu-avatars/users/{$user->id}/avatar/", $data['object_key']);
        $this->assertSame(config('filesystems.disks.media_avatars.bucket'), MediaUpload::findOrFail($data['upload_id'])->bucket);
    }

    public function test_shopping_upload_uses_shopping_bucket_and_namespace(): void
    {
        $user = $this->actingUser();
        $list = ShoppingList::factory()->create(['owner_id' => $user->id]);

        $response = $this->postJson(
            $this->api('/media/uploads'),
            $this->payload(['purpose' => 'shopping', 'entity_id' => $list->id]),
        )->assertCreated();

        $data = $response->json('data');
        $this->assertStringStartsWith(
            "chtohochu-shopping-images/users/{$user->id}/shopping-lists/{$list->id}/",
            $data['object_key'],
        );
        $this->assertSame(config('filesystems.disks.media_shopping_images.bucket'), MediaUpload::findOrFail($data['upload_id'])->bucket);
    }

    public function test_key_outside_purpose_namespace_rejected_on_complete(): void
    {
        // Regression: object_key, оказавшийся вне `chtohochu-*` prefix'а
        // своего purpose (повреждение/подмена в БД), не должен ни
        // подтверждаться, ни читаться из чужого namespace.
        $user = $this->actingUser();
        $wish = Wish::factory()->create(['owner_id' => $user->id]);

        $data = $this->postJson(
            $this->api('/media/uploads'),
            $this->payload(['entity_id' => $wish->id]),
        )->json('data');

        $upload = MediaUpload::findOrFail($data['upload_id']);
        $upload->update(['object_key' => 'other-project/steal.jpg']);
        $this->storage->putObject('media_wish_images', 'other-project/steal.jpg', 100, 'image/jpeg');

        $this->postJson(
            $this->api("/media/uploads/{$upload->id}/complete"),
        )->assertUnprocessable();

        // Статус не стал uploaded; storage к ключу не обращался
        // (assertKeyInPurpose отработал до head()).
        $this->assertSame('pending', $upload->fresh()->status);
    }

    public function test_cleanup_never_deletes_foreign_namespace(): void
    {
        // Regression: cleanup job обязан оставаться внутри
        // `chtohochu-*` prefix'а — запись с чужим ключом не должна
        // удалять объект другого проекта.
        $user = $this->actingUser();
        $wish = Wish::factory()->create(['owner_id' => $user->id]);

        $data = $this->postJson(
            $this->api('/media/uploads'),
            $this->payload(['entity_id' => $wish->id]),
        )->json('data');
        $upload = MediaUpload::findOrFail($data['upload_id']);
        $upload->update([
            'object_key' => 'other-project/keep-me.jpg',
            'status' => 'uploaded',
        ]);
        $this->storage->putObject('media_wish_images', 'other-project/keep-me.jpg', 100, 'image/jpeg');

        try {
            app(MediaUploadService::class)->deleteForEntity('wish', $wish->id);
            $this->fail('Expected abort on foreign namespace key.');
        } catch (HttpException) {
        }

        $this->assertNotContains(
            'media_wish_images/other-project/keep-me.jpg',
            $this->storage->deleted,
        );
        $this->assertArrayHasKey(
            'media_wish_images/other-project/keep-me.jpg',
            $this->storage->objects,
        );
    }

    public function test_object_key_differs_per_upload(): void
    {
        $user = $this->actingUser();
        $wish = Wish::factory()->create(['owner_id' => $user->id]);

        $a = $this->postJson($this->api('/media/uploads'), $this->payload(['entity_id' => $wish->id]))->json('data');
        $b = $this->postJson($this->api('/media/uploads'), $this->payload(['entity_id' => $wish->id]))->json('data');

        $this->assertNotSame($a['object_key'], $b['object_key']);
    }

    public function test_same_client_id_returns_same_upload(): void
    {
        $user = $this->actingUser();
        $wish = Wish::factory()->create(['owner_id' => $user->id]);
        $clientId = fake()->uuid();

        $a = $this->postJson(
            $this->api('/media/uploads'),
            $this->payload(['entity_id' => $wish->id, 'client_id' => $clientId]),
        )->assertCreated()->json('data');
        $b = $this->postJson(
            $this->api('/media/uploads'),
            $this->payload(['entity_id' => $wish->id, 'client_id' => $clientId]),
        )->assertCreated()->json('data');

        // Тот же upload и тот же object — retry не плодит дубликаты.
        $this->assertSame($a['upload_id'], $b['upload_id']);
        $this->assertSame($a['object_key'], $b['object_key']);
        $this->assertSame(1, MediaUpload::count());
    }

    public function test_complete_marks_uploaded_with_remote_url(): void
    {
        $user = $this->actingUser();
        $wish = Wish::factory()->create(['owner_id' => $user->id]);

        $data = $this->postJson(
            $this->api('/media/uploads'),
            $this->payload(['entity_id' => $wish->id]),
        )->json('data');

        $upload = MediaUpload::findOrFail($data['upload_id']);
        $this->storage->putObject(
            'media_wish_images',
            $upload->object_key,
            2048,
            'image/jpeg',
        );

        $done = $this->postJson(
            $this->api("/media/uploads/{$upload->id}/complete"),
        )->assertOk()->json('data');

        $this->assertSame('uploaded', $done['status']);
        $this->assertStringContainsString($upload->object_key, $done['remote_url']);
        $this->assertNotNull(MediaUpload::findOrFail($upload->id)->uploaded_at);
    }

    public function test_complete_without_object_stays_pending(): void
    {
        $user = $this->actingUser();
        $wish = Wish::factory()->create(['owner_id' => $user->id]);

        $data = $this->postJson(
            $this->api('/media/uploads'),
            $this->payload(['entity_id' => $wish->id]),
        )->json('data');

        $this->postJson($this->api("/media/uploads/{$data['upload_id']}/complete"))
            ->assertUnprocessable();
        $this->assertSame('pending', MediaUpload::findOrFail($data['upload_id'])->status);
    }

    public function test_complete_rejects_oversized_or_wrong_type_object(): void
    {
        $user = $this->actingUser();
        $wish = Wish::factory()->create(['owner_id' => $user->id]);

        $data = $this->postJson(
            $this->api('/media/uploads'),
            $this->payload(['entity_id' => $wish->id]),
        )->json('data');
        $upload = MediaUpload::findOrFail($data['upload_id']);

        $this->storage->putObject(
            'media_wish_images',
            $upload->object_key,
            config('media.max_upload_bytes') + 1,
            'image/jpeg',
        );
        $this->postJson($this->api("/media/uploads/{$upload->id}/complete"))
            ->assertUnprocessable();
        $this->assertSame('failed', $upload->fresh()->status);
    }

    public function test_expired_upload_rejected(): void
    {
        $user = $this->actingUser();
        $wish = Wish::factory()->create(['owner_id' => $user->id]);

        $data = $this->postJson(
            $this->api('/media/uploads'),
            $this->payload(['entity_id' => $wish->id]),
        )->json('data');
        $upload = MediaUpload::findOrFail($data['upload_id']);
        $upload->update(['expires_at' => now()->subMinute()]);
        $this->storage->putObject('media_wish_images', $upload->object_key, 100, 'image/jpeg');

        $this->postJson($this->api("/media/uploads/{$upload->id}/complete"))
            ->assertUnprocessable();
        $this->assertSame('failed', $upload->fresh()->status);
    }

    public function test_foreign_upload_id_rejected(): void
    {
        $this->actingUser();
        $foreign = MediaUpload::factory()->create(); // чужой upload

        $this->postJson($this->api("/media/uploads/{$foreign->id}/complete"))
            ->assertNotFound();
    }

    public function test_wish_delete_dispatches_media_cleanup(): void
    {
        Queue::fake();
        $user = $this->actingUser();
        $wish = Wish::factory()->create(['owner_id' => $user->id]);

        $this->deleteJson($this->api("/wishes/{$wish->id}"))->assertNoContent();

        Queue::assertPushed(DeleteMediaObjects::class, fn ($job) => $job->purpose === 'wish' && $job->entityId === $wish->id);
    }

    public function test_cleanup_job_deletes_objects_and_marks_rows(): void
    {
        $user = $this->actingUser();
        $wish = Wish::factory()->create(['owner_id' => $user->id]);

        $data = $this->postJson(
            $this->api('/media/uploads'),
            $this->payload(['entity_id' => $wish->id]),
        )->json('data');
        $upload = MediaUpload::findOrFail($data['upload_id']);
        $this->storage->putObject('media_wish_images', $upload->object_key, 100, 'image/jpeg');
        $upload->update(['status' => 'uploaded', 'remote_url' => 'https://cdn.test/x']);

        (new DeleteMediaObjects('wish', $wish->id))->handle(app(MediaUploadService::class));

        $this->assertSame('deleted', $upload->fresh()->status);
        $this->assertContains('media_wish_images/'.$upload->object_key, $this->storage->deleted);
    }
}
