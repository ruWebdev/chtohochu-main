<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Участники совместных списков покупок.
     *
     * Owner хранится в shopping_lists.owner_id и является участником
     * неявно — в pivot его нет (единственный источник владения).
     * Уникальная пара (list_id, user_id) — первичный ключ.
     */
    public function up(): void
    {
        Schema::create('shopping_list_members', function (Blueprint $table) {
            $table->foreignUuid('list_id')->constrained('shopping_lists')->cascadeOnDelete();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->timestamps();

            $table->primary(['list_id', 'user_id']);

            // «В каких списках я участник» — по user_id.
            $table->index('user_id');
        });

        // Монотонная ревизия сущности для realtime-конверта
        // (docs/20-backend/realtime-events.md §2). Инкремент — в той
        // же транзакции, что и мутация.
        Schema::table('shopping_lists', function (Blueprint $table) {
            $table->unsignedBigInteger('revision')->default(0);
        });
        Schema::table('shopping_items', function (Blueprint $table) {
            $table->unsignedBigInteger('revision')->default(0);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('shopping_items', function (Blueprint $table) {
            $table->dropColumn('revision');
        });
        Schema::table('shopping_lists', function (Blueprint $table) {
            $table->dropColumn('revision');
        });
        Schema::dropIfExists('shopping_list_members');
    }
};
