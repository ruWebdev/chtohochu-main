<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Дополнительные изображения желания (мультифото).
     *
     * `wishes.image_url` остаётся primary-изображением — обратная
     * совместимость со старыми клиентами. Здесь живут только
     * additional, упорядоченные `sort_order` (1..N).
     *
     * `id` — клиентский UUID (совпадает с `client_id` media upload):
     * даёт идемпотентность при повторных PATCH и связь с журналом
     * media_uploads для очистки объектов удалённых изображений.
     */
    public function up(): void
    {
        Schema::create('wish_images', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('wish_id')->constrained('wishes')->cascadeOnDelete();
            $table->text('url');
            $table->unsignedSmallInteger('sort_order');
            $table->timestamps();

            $table->index(['wish_id', 'sort_order']);
        });

        DB::statement(
            'ALTER TABLE wish_images ADD CONSTRAINT wish_images_sort_order_positive '
            .'CHECK (sort_order >= 1)'
        );
    }

    public function down(): void
    {
        Schema::dropIfExists('wish_images');
    }
};
