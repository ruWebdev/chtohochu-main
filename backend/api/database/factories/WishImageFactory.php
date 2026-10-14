<?php

namespace Database\Factories;

use App\Models\Wish;
use App\Models\WishImage;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/**
 * @extends Factory<WishImage>
 */
class WishImageFactory extends Factory
{
    protected $model = WishImage::class;

    public function definition(): array
    {
        return [
            'id' => Str::uuid()->toString(),
            'wish_id' => Wish::factory(),
            'url' => 'https://cdn.test/chtohochu-wish-images/'.Str::uuid().'.jpg',
            'sort_order' => 1,
        ];
    }
}
