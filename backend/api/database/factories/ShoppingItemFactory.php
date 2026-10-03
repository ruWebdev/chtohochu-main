<?php

namespace Database\Factories;

use App\Models\ShoppingItem;
use App\Models\ShoppingList;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<ShoppingItem>
 */
class ShoppingItemFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'list_id' => ShoppingList::factory(),
            'title' => fake()->words(2, true),
            'quantity' => fake()->numberBetween(1, 10),
            'is_checked' => false,
        ];
    }
}
