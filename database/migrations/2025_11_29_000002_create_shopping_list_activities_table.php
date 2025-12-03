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
        Schema::create('shopping_list_activities', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('shopping_list_id')->index();
            $table->uuid('user_id')->index();
            $table->string('action', 64);
            $table->json('data')->nullable();
            $table->timestamps();

            $table->foreign('shopping_list_id')
                ->references('id')
                ->on('shopping_lists')
                ->onDelete('cascade');

            $table->foreign('user_id')
                ->references('id')
                ->on('users')
                ->onDelete('cascade');
        });
    }

    /**
     * Отменить миграции.
     */
    public function down(): void
    {
        Schema::dropIfExists('shopping_list_activities');
    }
};
