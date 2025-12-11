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
        Schema::table('shopping_lists', function (Blueprint $table) {
            if (! Schema::hasColumn('shopping_lists', 'card_color')) {
                $table->string('card_color', 9)->nullable()->after('avatar');
            }
        });
    }

    /**
     * Отменить миграции.
     */
    public function down(): void
    {
        Schema::table('shopping_lists', function (Blueprint $table) {
            if (Schema::hasColumn('shopping_lists', 'card_color')) {
                $table->dropColumn('card_color');
            }
        });
    }
};
