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
        Schema::create('shopping_items', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('list_id')->constrained('shopping_lists')->cascadeOnDelete();
            $table->string('title', 200);
            $table->integer('quantity')->default(1);
            $table->boolean('is_checked')->default(false);
            $table->timestamps();

            $table->index('list_id');
        });

        // Количество строго положительное на уровне БД.
        DB::statement(
            'ALTER TABLE shopping_items ADD CONSTRAINT shopping_items_quantity_positive CHECK (quantity >= 1)'
        );
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('shopping_items');
    }
};
