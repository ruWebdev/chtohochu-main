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
        Schema::table('shopping_lists', function (Blueprint $table) {
            $table->boolean('notifications_enabled')->default(false)->after('avatar');
            $table->dateTime('deadline_at')->nullable()->after('notifications_enabled');
            $table->string('event_name')->nullable()->after('deadline_at');
            $table->integer('sort_order')->default(0)->after('event_name');
        });
    }

    /**
     * Отменить миграции.
     */
    public function down(): void
    {
        Schema::table('shopping_lists', function (Blueprint $table) {
            $table->dropColumn([
                'notifications_enabled',
                'deadline_at',
                'event_name',
                'sort_order',
            ]);
        });
    }
};
