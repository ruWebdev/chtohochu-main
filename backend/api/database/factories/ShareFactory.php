<?php

namespace Database\Factories;

use App\Models\Share;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/**
 * @extends Factory<Share>
 */
class ShareFactory extends Factory
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
            // Токен в том же формате, что у контроллера: 32 байта,
            // base64url — 43 символа, ~256 бит энтропии.
            'token' => Str::random(43),
        ];
    }
}
