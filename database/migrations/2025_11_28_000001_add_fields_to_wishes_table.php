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
        Schema::table('wishes', function (Blueprint $table) {
            $table->string('url', 2048)->nullable()->after('description');
            $table->decimal('price_min', 15, 2)->nullable()->after('desired_price');
            $table->decimal('price_max', 15, 2)->nullable()->after('price_min');
            $table->string('priority', 32)->nullable()->after('price_max');
            $table->json('tags')->nullable()->after('priority');
            $table->boolean('reminder_enabled')->default(false)->after('tags');
            $table->dateTime('reminder_at')->nullable()->after('reminder_enabled');
            $table->dateTime('deadline_at')->nullable()->after('reminder_at');
            $table->uuid('executor_user_id')->nullable()->after('deadline_at');

            $table->foreign('executor_user_id')
                ->references('id')
                ->on('users')
                ->onDelete('set null');
        });
    }

    /**
     * Отменить миграции.
     */
    public function down(): void
    {
        Schema::table('wishes', function (Blueprint $table) {
            $table->dropForeign(['executor_user_id']);
            $table->dropColumn([
                'url',
                'price_min',
                'price_max',
                'priority',
                'tags',
                'reminder_enabled',
                'reminder_at',
                'deadline_at',
                'executor_user_id',
            ]);
        });
    }
};
