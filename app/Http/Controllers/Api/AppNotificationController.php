<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AppNotification;
use Illuminate\Http\Request;

/**
 * Контроллер для работы с уведомлениями приложения.
 */
class AppNotificationController extends Controller
{
    /**
     * Получить список уведомлений текущего пользователя.
     */
    public function index(Request $request)
    {
        $user = $request->user();

        $notifications = AppNotification::query()
            ->where('user_id', $user->id)
            ->orderByDesc('created_at')
            ->limit(50)
            ->get();

        return response()->json([
            'data' => $notifications,
            'unread_count' => AppNotification::query()
                ->where('user_id', $user->id)
                ->where('is_read', false)
                ->count(),
        ]);
    }

    /**
     * Получить количество непрочитанных уведомлений.
     */
    public function unreadCount(Request $request)
    {
        $user = $request->user();

        $count = AppNotification::query()
            ->where('user_id', $user->id)
            ->where('is_read', false)
            ->count();

        return response()->json([
            'unread_count' => $count,
        ]);
    }

    /**
     * Пометить уведомление как прочитанное.
     */
    public function markAsRead(Request $request, AppNotification $notification)
    {
        $user = $request->user();

        if ($notification->user_id !== $user->id) {
            abort(403);
        }

        $notification->markAsRead();

        return response()->json([
            'message' => __('notifications.marked_as_read'),
        ]);
    }

    /**
     * Пометить все уведомления как прочитанные.
     */
    public function markAllAsRead(Request $request)
    {
        $user = $request->user();

        AppNotification::query()
            ->where('user_id', $user->id)
            ->where('is_read', false)
            ->update(['is_read' => true]);

        return response()->json([
            'message' => __('notifications.all_marked_as_read'),
        ]);
    }

    /**
     * Удалить уведомление.
     */
    public function destroy(Request $request, AppNotification $notification)
    {
        $user = $request->user();

        if ($notification->user_id !== $user->id) {
            abort(403);
        }

        $notification->delete();

        return response()->json([
            'message' => __('notifications.deleted'),
        ]);
    }
}
