<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class BroadcastAuthTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        // phpunit.xml форсит BROADCAST_CONNECTION=null — события в тестах
        // не уходят в сеть. Здесь нужен реальный PusherBroadcaster: подпись
        // канала считается локально (HMAC), сеть не задействована.
        // Каналы из routes/channels.php регистрируются на default-драйвере
        // при boot, поэтому после переключения на reverb файл нужно
        // подключить повторно.
        config(['broadcasting.default' => 'reverb']);
        require base_path('routes/channels.php');
    }

    public function test_broadcast_auth_requires_authentication(): void
    {
        $this->postJson($this->api('/broadcasting/auth'), [
            'socket_id' => '1234.5678',
            'channel_name' => 'private-user.00000000-0000-0000-0000-000000000000',
        ])->assertUnauthorized();
    }

    public function test_broadcast_auth_authorizes_own_user_channel(): void
    {
        $user = User::factory()->create();
        $token = $user->createToken('test')->plainTextToken;

        $response = $this->withToken($token)->postJson($this->api('/broadcasting/auth'), [
            'socket_id' => '1234.5678',
            'channel_name' => "private-user.{$user->id}",
        ]);

        $response->assertOk()->assertJsonStructure(['auth']);

        $this->assertStringStartsWith(
            config('broadcasting.connections.reverb.key').':',
            $response->json('auth'),
        );
    }

    public function test_broadcast_auth_denies_other_users_channel(): void
    {
        $user = User::factory()->create();
        $token = $user->createToken('test')->plainTextToken;
        $other = User::factory()->create();

        $this->withToken($token)->postJson($this->api('/broadcasting/auth'), [
            'socket_id' => '1234.5678',
            'channel_name' => "private-user.{$other->id}",
        ])->assertForbidden();
    }

    public function test_broadcast_auth_denies_other_users_notification_channel(): void
    {
        // Регрессия: User::id — UUID. Приведение к int в колбэке канала
        // делало проверку всегда истинной для любого id.
        $user = User::factory()->create();
        $token = $user->createToken('test')->plainTextToken;
        $other = User::factory()->create();

        $this->withToken($token)->postJson($this->api('/broadcasting/auth'), [
            'socket_id' => '1234.5678',
            'channel_name' => "private-App.Models.User.{$other->id}",
        ])->assertForbidden();
    }

    public function test_broadcast_auth_denies_unknown_channel(): void
    {
        $user = User::factory()->create();
        $token = $user->createToken('test')->plainTextToken;

        $this->withToken($token)->postJson($this->api('/broadcasting/auth'), [
            'socket_id' => '1234.5678',
            'channel_name' => 'private-nonexistent.1',
        ])->assertForbidden();
    }
}
