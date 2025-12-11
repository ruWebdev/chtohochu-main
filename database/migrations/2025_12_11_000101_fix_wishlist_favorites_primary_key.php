<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('wishlist_favorites', function (Blueprint $table) {
            // Убираем первичный ключ по полю id и само поле id
            $table->dropPrimary();
            $table->dropColumn('id');
        });

        Schema::table('wishlist_favorites', function (Blueprint $table) {
            // Делаем составной первичный ключ, как в других pivot-таблицах
            $table->primary(['user_id', 'wishlist_id']);
        });
    }

    public function down(): void
    {
        Schema::table('wishlist_favorites', function (Blueprint $table) {
            // Откатываемся к схеме с отдельным UUID-ключом id
            $table->dropPrimary(['user_id', 'wishlist_id']);
            $table->uuid('id')->primary();
        });
    }
};
