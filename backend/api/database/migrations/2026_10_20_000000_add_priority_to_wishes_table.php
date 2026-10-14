<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Приоритет желания: later | normal | high (default 'normal').
     *
     * Скалярное поле, а не отдельные сущности/таблицы: группировка
     * выполняется клиентом на уровне интерфейса. Существующие строки
     * получают 'normal' через DEFAULT — дополнительный backfill
     * не нужен.
     */
    public function up(): void
    {
        Schema::table('wishes', function (Blueprint $table) {
            $table->string('priority', 16)->default('normal');
        });

        DB::statement(
            'ALTER TABLE wishes ADD CONSTRAINT wishes_priority_valid '
            ."CHECK (priority IN ('later', 'normal', 'high'))"
        );
    }

    public function down(): void
    {
        DB::statement('ALTER TABLE wishes DROP CONSTRAINT wishes_priority_valid');
        Schema::table('wishes', function (Blueprint $table) {
            $table->dropColumn('priority');
        });
    }
};
