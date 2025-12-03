<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('wishlists', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('owner_id')->index();
            $table->string('name');
            $table->string('visibility', 32)->default('personal');
            $table->string('status', 32)->default('new');
            $table->string('avatar')->nullable();
            $table->timestamps();

            $table->foreign('owner_id')
                ->references('id')
                ->on('users')
                ->onDelete('cascade');
        });

        Schema::create('wishes', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('wishlist_id')->index();
            $table->string('name');
            $table->string('visibility', 32)->default('personal');
            $table->json('images')->nullable();
            $table->string('necessity', 32)->default('later');
            $table->text('description')->nullable();
            $table->decimal('desired_price', 15, 2)->nullable();
            $table->string('status', 32)->default('not_fulfilled');
            $table->timestamps();

            $table->foreign('wishlist_id')
                ->references('id')
                ->on('wishlists')
                ->onDelete('cascade');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('wishes');
        Schema::dropIfExists('wishlists');
    }
};
