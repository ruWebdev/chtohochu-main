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
        Schema::table('users', function (Blueprint $table) {
            $table->string('vk_id')->nullable()->unique()->after('id');
        });
    }

    /**
     * Отменить миграции.
     */
    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropUnique(['vk_id']);
            $table->dropColumn('vk_id');
        });
    }
};
