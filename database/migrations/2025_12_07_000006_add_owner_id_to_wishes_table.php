<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Выполнить миграции.
     */
    public function up(): void
    {
        Schema::table('wishes', function (Blueprint $table) {
            $table->uuid('owner_id')->nullable()->after('wishlist_id');
        });

        // Заполняем owner_id для существующих желаний на основе владельца списка
        DB::table('wishes')
            ->join('wishlists', 'wishes.wishlist_id', '=', 'wishlists.id')
            ->update(['wishes.owner_id' => DB::raw('wishlists.owner_id')]);

        Schema::table('wishes', function (Blueprint $table) {
            $table->foreign('owner_id')
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
        Schema::table('wishes', function (Blueprint $table) {
            $table->dropForeign(['owner_id']);
            $table->dropColumn('owner_id');
        });
    }
};
