<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('wishlists', function (Blueprint $table) {
            // Новые флаги по спецификации
            $table->boolean('allow_claiming')->default(true)->after('avatar');
            $table->boolean('show_claimers')->default(true)->after('allow_claiming');

            // Переименование/доп. поля для сортировки и категорий
            // Оставляем существующие поля, маппинг сделаем на уровне ресурса.
            // При необходимости можно будет выполнить отдельные rename-миграции.
        });

        Schema::table('wishes', function (Blueprint $table) {
            // Скрытие цены и управление бронированием
            $table->boolean('hide_price')->default(false)->after('price_max');
            $table->boolean('allow_claiming')->default(true)->after('hide_price');

            // Позиция в списке и флаг "в процессе" (дополнительно к status)
            $table->integer('sort_index')->default(0)->after('status');
            $table->boolean('in_progress')->default(false)->after('sort_index');
        });
    }

    public function down(): void
    {
        Schema::table('wishlists', function (Blueprint $table) {
            $table->dropColumn(['allow_claiming', 'show_claimers']);
        });

        Schema::table('wishes', function (Blueprint $table) {
            $table->dropColumn(['hide_price', 'allow_claiming', 'sort_index', 'in_progress']);
        });
    }
};
