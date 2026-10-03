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
        Schema::create('wishes', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('owner_id')->constrained('users')->cascadeOnDelete();
            $table->string('title', 100);
            $table->text('description')->nullable();
            $table->bigInteger('price')->nullable(); // целые рубли
            $table->text('link')->nullable();
            $table->text('image_url')->nullable();
            $table->timestamps();

            $table->index(['owner_id', 'created_at']);
        });

        // Цена неотрицательная на уровне БД.
        DB::statement(
            'ALTER TABLE wishes ADD CONSTRAINT wishes_price_non_negative CHECK (price IS NULL OR price >= 0)'
        );
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('wishes');
    }
};
