<?php

namespace Database\Factories;

use App\Models\Friendship;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Friendship>
 */
class FriendshipFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * Пара нормализуется в configure(): user_id < friend_id.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'friend_id' => User::factory(),
            'initiator_id' => fn (array $attributes) => $attributes['user_id'],
            'status' => 'accepted',
        ];
    }

    /**
     * Нормализуем пару и гарантируем user_id <> friend_id.
     */
    public function configure(): static
    {
        return $this->afterMaking(function ($friendship) {
            if ($friendship->user_id === $friendship->friend_id) {
                $friendship->friend_id = User::factory()->create()->id;
            }

            [$userId, $friendId] = Friendship::normalizePair(
                $friendship->user_id,
                $friendship->friend_id,
            );

            $friendship->user_id = $userId;
            $friendship->friend_id = $friendId;
        });
    }
}
