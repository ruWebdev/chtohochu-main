<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('wish_claims', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('wish_id');
            $table->uuid('user_id');
            $table->timestamp('claimed_at')->nullable();
            $table->boolean('is_secret')->default(false);
            $table->timestamps();

            $table->foreign('wish_id')->references('id')->on('wishes')->onDelete('cascade');
            $table->foreign('user_id')->references('id')->on('users')->onDelete('cascade');
            $table->unique(['wish_id', 'user_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('wish_claims');
    }
};
