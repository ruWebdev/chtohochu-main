<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Журнал media-загрузок (ADR-015): presigned PUT → complete.
     * object_key генерируется только сервером; клиент никогда не
     * присылает bucket/key — ownership фиксируется в строке.
     */
    public function up(): void
    {
        Schema::create('media_uploads', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('purpose', 20); // avatar | wish | shopping
            $table->uuid('entity_id')->nullable(); // wish/list id; null для avatar
            $table->uuid('client_id')->nullable(); // клиентский id → идемпотентность
            $table->string('bucket');
            $table->text('object_key');
            $table->string('content_type', 100);
            $table->unsignedBigInteger('declared_size');
            $table->string('status', 20)->default('pending');
            $table->text('remote_url')->nullable();
            $table->timestamp('expires_at');
            $table->timestamp('uploaded_at')->nullable();
            $table->timestamps();

            $table->unique(['user_id', 'client_id']);
            $table->index(['user_id', 'status']);
            $table->index(['purpose', 'entity_id']);
        });

        DB::statement(
            'ALTER TABLE media_uploads ADD CONSTRAINT media_uploads_status_check '
            ."CHECK (status IN ('pending','uploading','uploaded','failed','deleted'))"
        );
        DB::statement(
            'ALTER TABLE media_uploads ADD CONSTRAINT media_uploads_purpose_check '
            ."CHECK (purpose IN ('avatar','wish','shopping'))"
        );
    }

    public function down(): void
    {
        Schema::dropIfExists('media_uploads');
    }
};
