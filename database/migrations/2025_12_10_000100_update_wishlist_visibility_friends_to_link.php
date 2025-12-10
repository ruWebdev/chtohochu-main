<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::table('wishlists')
            ->where('visibility', 'friends')
            ->update(['visibility' => 'link']);

        DB::table('wishes')
            ->where('visibility', 'friends')
            ->update(['visibility' => 'link']);
    }

    public function down(): void
    {
        DB::table('wishlists')
            ->where('visibility', 'link')
            ->update(['visibility' => 'friends']);

        DB::table('wishes')
            ->where('visibility', 'link')
            ->update(['visibility' => 'friends']);
    }
};
