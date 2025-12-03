<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('shopping_lists', function (Blueprint $table) {
            // Видимость списка (personal|friends|public), по умолчанию personal
            $table->string('visibility')->default('personal')->after('description');
        });

        Schema::table('shopping_list_items', function (Blueprint $table) {
            $table->string('image_url')->nullable()->after('name');
            $table->unsignedInteger('quantity')->default(1)->after('image_url');
            $table->string('unit', 32)->nullable()->after('quantity');
            $table->string('priority', 32)->nullable()->after('unit');
            $table->uuid('completed_by')->nullable()->after('is_purchased');
            $table->timestamp('completed_at')->nullable()->after('completed_by');
            $table->date('event_date')->nullable()->after('assigned_user_id');
            $table->text('note')->nullable()->after('event_date');

            $table->foreign('completed_by')
                ->references('id')
                ->on('users')
                ->onDelete('set null');
        });
    }

    public function down(): void
    {
        Schema::table('shopping_lists', function (Blueprint $table) {
            $table->dropColumn('visibility');
        });

        Schema::table('shopping_list_items', function (Blueprint $table) {
            $table->dropForeign(['completed_by']);
            $table->dropColumn([
                'image_url',
                'quantity',
                'unit',
                'priority',
                'completed_by',
                'completed_at',
                'event_date',
                'note',
            ]);
        });
    }
};
