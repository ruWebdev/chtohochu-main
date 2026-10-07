<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     *
     * Membership wish ↔ wish_list: желание входит максимум в
     * один список (null = вне списков). Список и желание —
     * одного пользователя (валидируется в Form Request);
     * nullOnDelete — задел под hard-delete cleanup, текущий
     * контроллер разгруппировывает wishes при soft-delete сам.
     */
    public function up(): void
    {
        Schema::table('wishes', function (Blueprint $table) {
            $table->foreignUuid('list_id')
                ->nullable()
                ->constrained('wish_lists')
                ->nullOnDelete();

            $table->index(['owner_id', 'list_id']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('wishes', function (Blueprint $table) {
            $table->dropIndex(['owner_id', 'list_id']);
            $table->dropConstrainedForeignId('list_id');
        });
    }
};
