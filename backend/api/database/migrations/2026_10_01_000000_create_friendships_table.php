<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('friendships', function (Blueprint $table) {
            $table->uuid('id')->primary();
            // Нормализованная пара: user_id < friend_id (обеспечивает код).
            // Одна запись на пару друзей — дружба симметрична.
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignUuid('friend_id')->constrained('users')->cascadeOnDelete();
            $table->foreignUuid('initiator_id')->constrained('users')->cascadeOnDelete();
            // MVP: существует только 'accepted'.
            $table->string('status')->default('accepted');
            $table->timestamps();

            $table->unique(['user_id', 'friend_id']);
            $table->index('friend_id');
        });

        // Нельзя подружиться с самим собой.
        DB::statement(
            'ALTER TABLE friendships ADD CONSTRAINT friendships_no_self CHECK (user_id <> friend_id)'
        );
        // Нормализация пары на уровне БД.
        DB::statement(
            'ALTER TABLE friendships ADD CONSTRAINT friendships_normalized_pair CHECK (user_id < friend_id)'
        );
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('friendships');
    }
};
