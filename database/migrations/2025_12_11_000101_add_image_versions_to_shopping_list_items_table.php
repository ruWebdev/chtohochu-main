<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Выполнить миграции.
     */
    public function up(): void
    {
        Schema::table('shopping_list_items', function (Blueprint $table) {
            $table->string('image_full_url', 2048)->nullable()->after('image_url');
            $table->string('image_preview_url', 2048)->nullable()->after('image_full_url');
            $table->string('image_thumb_url', 2048)->nullable()->after('image_preview_url');
        });
    }

    /**
     * Отменить миграции.
     */
    public function down(): void
    {
        Schema::table('shopping_list_items', function (Blueprint $table) {
            $table->dropColumn([
                'image_full_url',
                'image_preview_url',
                'image_thumb_url',
            ]);
        });
    }
};
