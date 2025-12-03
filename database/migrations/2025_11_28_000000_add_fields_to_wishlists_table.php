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
        Schema::table('wishlists', function (Blueprint $table) {
            $table->text('description')->nullable()->after('name');
            $table->string('wishes_sort', 32)->default('created_at')->after('avatar');
            $table->json('tags')->nullable()->after('wishes_sort');
            $table->boolean('reminder_enabled')->default(false)->after('tags');
            $table->dateTime('reminder_at')->nullable()->after('reminder_enabled');
        });
    }

    /**
     * Отменить миграции.
     */
    public function down(): void
    {
        Schema::table('wishlists', function (Blueprint $table) {
            $table->dropColumn([
                'description',
                'wishes_sort',
                'tags',
                'reminder_enabled',
                'reminder_at',
            ]);
        });
    }
};
