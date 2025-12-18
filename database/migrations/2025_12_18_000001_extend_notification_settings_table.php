<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Расширение таблицы настроек уведомлений согласно спецификации.
 * Добавляет гранулярные настройки для всех типов событий.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('notification_settings', function (Blueprint $table) {
            // Группа: Участие в списках
            $table->boolean('list_invites')->default(true)->after('new_wishes');
            $table->boolean('list_member_changes')->default(true)->after('list_invites');

            // Группа: Желания
            $table->boolean('wish_comments')->default(true)->after('list_member_changes');

            // Группа: Списки покупок
            $table->boolean('shopping_list_invites')->default(true)->after('wish_comments');
            $table->boolean('shopping_member_changes')->default(true)->after('shopping_list_invites');
            $table->boolean('shopping_item_checked')->default(true)->after('shopping_member_changes');

            // Группа: Системные
            $table->boolean('system_announcements')->default(true)->after('shopping_item_checked');
        });
    }

    public function down(): void
    {
        Schema::table('notification_settings', function (Blueprint $table) {
            $table->dropColumn([
                'list_invites',
                'list_member_changes',
                'wish_comments',
                'shopping_list_invites',
                'shopping_member_changes',
                'shopping_item_checked',
                'system_announcements',
            ]);
        });
    }
};
