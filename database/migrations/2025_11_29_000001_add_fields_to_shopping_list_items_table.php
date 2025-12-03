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
            $table->integer('sort_index')->default(0)->after('is_purchased');
            $table->uuid('assigned_user_id')->nullable()->after('sort_index');

            $table->foreign('assigned_user_id')
                ->references('id')
                ->on('users')
                ->onDelete('set null');
        });
    }

    /**
     * Отменить миграции.
     */
    public function down(): void
    {
        Schema::table('shopping_list_items', function (Blueprint $table) {
            $table->dropForeign(['assigned_user_id']);
            $table->dropColumn([
                'sort_index',
                'assigned_user_id',
            ]);
        });
    }
};
