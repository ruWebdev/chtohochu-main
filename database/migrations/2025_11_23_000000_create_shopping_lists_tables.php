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
        Schema::create('shopping_lists', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('owner_id')->index();
            $table->string('name');
            $table->text('description')->nullable();
            $table->boolean('is_shared')->default(false);
            $table->string('status', 32)->default('new');
            $table->string('avatar')->nullable();
            $table->timestamps();

            $table->foreign('owner_id')
                ->references('id')
                ->on('users')
                ->onDelete('cascade');
        });

        Schema::create('shopping_list_items', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('shopping_list_id')->index();
            $table->string('name');
            $table->boolean('is_purchased')->default(false);
            $table->timestamps();

            $table->foreign('shopping_list_id')
                ->references('id')
                ->on('shopping_lists')
                ->onDelete('cascade');
        });

        Schema::create('shopping_list_user', function (Blueprint $table) {
            $table->uuid('shopping_list_id');
            $table->uuid('user_id');
            $table->timestamps();

            $table->primary(['shopping_list_id', 'user_id']);

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
        Schema::dropIfExists('shopping_list_user');
        Schema::dropIfExists('shopping_list_items');
        Schema::dropIfExists('shopping_lists');
    }
};
