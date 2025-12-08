<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('friendships', function (Blueprint $table) {
            $table->text('message')->nullable()->after('status');
            $table->index(['addressee_id', 'status'], 'friendships_addressee_status_index');
            $table->index(['requester_id', 'status'], 'friendships_requester_status_index');
        });
    }

    public function down(): void
    {
        Schema::table('friendships', function (Blueprint $table) {
            $table->dropIndex('friendships_addressee_status_index');
            $table->dropIndex('friendships_requester_status_index');
            $table->dropColumn('message');
        });
    }
};
