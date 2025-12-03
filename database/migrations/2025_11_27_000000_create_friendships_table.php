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
        Schema::create('friendships', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('requester_id')->index();
            $table->uuid('addressee_id')->index();
            $table->string('status', 32)->default('pending');
            $table->timestamps();

            $table->foreign('requester_id')
                ->references('id')
                ->on('users')
                ->onDelete('cascade');

            $table->foreign('addressee_id')
                ->references('id')
                ->on('users')
                ->onDelete('cascade');

            $table->unique(['requester_id', 'addressee_id']);
        });
    }

    /**
     * Отменить миграции.
     */
    public function down(): void
    {
        Schema::dropIfExists('friendships');
    }
};
