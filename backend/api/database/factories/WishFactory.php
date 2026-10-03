<?php

namespace Database\Factories;

use App\Models\User;
use App\Models\Wish;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Wish>
 */
class WishFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'owner_id' => User::factory(),
            'title' => fake()->sentence(3),
            'description' => fake()->optional()->paragraph(),
            'price' => fake()->optional()->numberBetween(100, 100000),
            'link' => fake()->optional()->url(),
            'image_url' => fake()->optional()->imageUrl(),
        ];
    }
}
