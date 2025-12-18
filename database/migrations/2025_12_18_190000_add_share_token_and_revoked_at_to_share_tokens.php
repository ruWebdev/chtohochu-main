<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Добавляет поля share_token и revoked_at в таблицу share_tokens
 * для поддержки уникальных токенов и отзыва ссылок.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('share_tokens', function (Blueprint $table) {
            // Уникальный токен для ссылки (вместо использования id)
            $table->string('share_token', 64)->unique()->after('id');
            // Дата отзыва ссылки
            $table->timestamp('revoked_at')->nullable()->after('expires_at');
            // Метаданные для аналитики
            $table->string('title')->nullable()->after('role');
            $table->text('description')->nullable()->after('title');
            $table->string('preview_image_url')->nullable()->after('description');
        });
    }

    public function down(): void
    {
        Schema::table('share_tokens', function (Blueprint $table) {
            $table->dropColumn(['share_token', 'revoked_at', 'title', 'description', 'preview_image_url']);
        });
    }
};
