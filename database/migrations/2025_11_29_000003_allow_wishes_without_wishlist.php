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
        // Сначала удаляем существующий внешний ключ, чтобы изменить столбец
        Schema::table('wishes', function (Blueprint $table) {
            $table->dropForeign(['wishlist_id']);
        });

        // Делаем wishlist_id nullable и возвращаем внешний ключ
        Schema::table('wishes', function (Blueprint $table) {
            $table->uuid('wishlist_id')->nullable()->change();

            $table->foreign('wishlist_id')
                ->references('id')
                ->on('wishlists')
                ->onDelete('cascade');
        });
    }

    /**
     * Отменить миграции.
     */
    public function down(): void
    {
        // Откатываем изменение: снова делаем wishlist_id обязательным
        Schema::table('wishes', function (Blueprint $table) {
            $table->dropForeign(['wishlist_id']);
        });

        Schema::table('wishes', function (Blueprint $table) {
            $table->uuid('wishlist_id')->nullable(false)->change();

            $table->foreign('wishlist_id')
                ->references('id')
                ->on('wishlists')
                ->onDelete('cascade');
        });
    }
};
