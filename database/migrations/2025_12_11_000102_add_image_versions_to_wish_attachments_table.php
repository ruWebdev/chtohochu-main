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
        Schema::table('wish_attachments', function (Blueprint $table) {
            $table->string('preview_url', 2048)->nullable()->after('file_url');
            $table->string('thumbnail_url', 2048)->nullable()->after('preview_url');
        });
    }

    /**
     * Отменить миграции.
     */
    public function down(): void
    {
        Schema::table('wish_attachments', function (Blueprint $table) {
            $table->dropColumn([
                'preview_url',
                'thumbnail_url',
            ]);
        });
    }
};
