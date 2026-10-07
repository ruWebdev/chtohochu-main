<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('shares', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('owner_id')->constrained('users')->cascadeOnDelete();
            // Polymorphic shareable: 'App\Models\Wish' | 'App\Models\WishList'.
            // Тип и id разделены — один resolver для обеих сущностей,
            // задел под будущие типы (friends-scoped и др.).
            $table->string('shareable_type', 64);
            $table->uuid('shareable_id');
            // Capability token: генерируется только сервером, НЕ совпадает
            // с UUID сущности — ссылка не раскрывает id объекта.
            $table->string('token', 64)->unique();
            $table->timestamps();
            // Revoke без удаления строки (история + возможный аудит).
            $table->timestamp('revoked_at')->nullable();
            // Задел под expiry — в MVP всегда null.
            $table->timestamp('expires_at')->nullable();

            // Resolver: token → active share. Unique по token уже покрывает
            // точный lookup, составной — под выборку активных.
            $table->index(['token', 'revoked_at']);
            // «Один активный share на сущность» обеспечивается
            // идемпотентным create в контроллере (PostgreSQL partial
            // unique index не выразить через Blueprint кросс-БД).
            $table->index(['shareable_type', 'shareable_id']);
            $table->index(['owner_id', 'shareable_type', 'shareable_id']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('shares');
    }
};
