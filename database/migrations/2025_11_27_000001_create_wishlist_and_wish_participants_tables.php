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
        Schema::create('wishlist_user', function (Blueprint $table) {
            $table->uuid('wishlist_id');
            $table->uuid('user_id');
            $table->timestamps();

            $table->primary(['wishlist_id', 'user_id']);

            $table->foreign('wishlist_id')
                ->references('id')
                ->on('wishlists')
                ->onDelete('cascade');

            $table->foreign('user_id')
                ->references('id')
                ->on('users')
                ->onDelete('cascade');
        });

        Schema::create('wish_user', function (Blueprint $table) {
            $table->uuid('wish_id');
            $table->uuid('user_id');
            $table->timestamps();

            $table->primary(['wish_id', 'user_id']);

            $table->foreign('wish_id')
                ->references('id')
                ->on('wishes')
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
        Schema::dropIfExists('wish_user');
        Schema::dropIfExists('wishlist_user');
    }
};
