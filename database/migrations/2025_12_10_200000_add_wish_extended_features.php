<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Миграция для расширенного функционала желаний:
 * - Комментарии
 * - Лайки
 * - Чек-листы
 * - Приватные заметки
 * - История изменений
 * - Прикреплённые файлы
 * - Дополнительные настройки
 */
return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // Добавляем новые поля в таблицу wishes
        Schema::table('wishes', function (Blueprint $table) {
            // Приватные заметки владельца (только для него)
            $table->text('private_notes')->nullable()->after('description');

            // Чек-лист (JSON массив элементов)
            $table->json('checklist')->nullable()->after('private_notes');

            // Настройки видимости и прав
            $table->boolean('allow_comments')->default(true)->after('allow_claiming');
            $table->boolean('allow_sharing')->default(true)->after('allow_comments');

            // Информация о покупке
            $table->string('purchase_receipt')->nullable()->after('status');
            $table->timestamp('purchase_date')->nullable()->after('purchase_receipt');
        });

        // Таблица комментариев к желаниям
        Schema::create('wish_comments', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('wish_id')->index();
            $table->uuid('user_id')->index();
            $table->text('text');
            $table->timestamps();

            $table->foreign('wish_id')
                ->references('id')
                ->on('wishes')
                ->onDelete('cascade');

            $table->foreign('user_id')
                ->references('id')
                ->on('users')
                ->onDelete('cascade');
        });

        // Таблица лайков желаний
        Schema::create('wish_likes', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('wish_id')->index();
            $table->uuid('user_id')->index();
            $table->timestamp('created_at')->useCurrent();

            $table->foreign('wish_id')
                ->references('id')
                ->on('wishes')
                ->onDelete('cascade');

            $table->foreign('user_id')
                ->references('id')
                ->on('users')
                ->onDelete('cascade');

            // Один пользователь может лайкнуть желание только один раз
            $table->unique(['wish_id', 'user_id']);
        });

        // Таблица истории изменений желаний
        Schema::create('wish_history', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('wish_id')->index();
            $table->uuid('user_id')->index();
            $table->string('action', 32); // created, updated, status_changed, claimed, unclaimed
            $table->json('changes')->nullable(); // JSON с изменёнными полями
            $table->timestamp('created_at')->useCurrent();

            $table->foreign('wish_id')
                ->references('id')
                ->on('wishes')
                ->onDelete('cascade');

            $table->foreign('user_id')
                ->references('id')
                ->on('users')
                ->onDelete('cascade');
        });

        // Таблица прикреплённых файлов к желаниям
        Schema::create('wish_attachments', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('wish_id')->index();
            $table->string('file_name');
            $table->string('file_url');
            $table->string('file_type', 100); // mime type
            $table->unsignedBigInteger('file_size'); // bytes
            $table->timestamps();

            $table->foreign('wish_id')
                ->references('id')
                ->on('wishes')
                ->onDelete('cascade');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('wish_attachments');
        Schema::dropIfExists('wish_history');
        Schema::dropIfExists('wish_likes');
        Schema::dropIfExists('wish_comments');

        Schema::table('wishes', function (Blueprint $table) {
            $table->dropColumn([
                'private_notes',
                'checklist',
                'allow_comments',
                'allow_sharing',
                'purchase_receipt',
                'purchase_date',
            ]);
        });
    }
};
