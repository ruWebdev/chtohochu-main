<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Миграция для создания таблицы состояния индикаторов bottom navigation bar.
 * Хранит флаги наличия непрочитанных изменений по разделам для каждого пользователя.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('bottom_nav_badges', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')
                ->constrained()
                ->cascadeOnDelete();
            
            // Флаги индикаторов по разделам
            $table->boolean('wishlist')->default(false)->comment('Индикатор раздела ЧтоХочу');
            $table->boolean('purchases')->default(false)->comment('Индикатор раздела Покупки');
            $table->boolean('friends')->default(false)->comment('Индикатор раздела Друзья');
            
            $table->timestamps();
            
            // Уникальный индекс — один пользователь = одна запись
            $table->unique('user_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('bottom_nav_badges');
    }
};
