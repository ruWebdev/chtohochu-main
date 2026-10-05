<?php

namespace Database\Factories;

use App\Models\MediaUpload;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<MediaUpload>
 */
class MediaUploadFactory extends Factory
{
    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'purpose' => 'wish',
            'entity_id' => null,
            'client_id' => null,
            'bucket' => 'chtohochu-wish-images',
            'object_key' => 'users/'.fake()->uuid().'/wishes/x/'.fake()->uuid().'.jpg',
            'content_type' => 'image/jpeg',
            'declared_size' => 1024,
            'status' => 'pending',
            'expires_at' => now()->addMinutes(10),
        ];
    }
}
