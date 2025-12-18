<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\HealthController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\FcmTokenController;
use App\Http\Controllers\Api\ShoppingListController;
use App\Http\Controllers\Api\ShoppingListItemController;
use App\Http\Controllers\Api\WishlistController;
use App\Http\Controllers\Api\WishController;
use App\Http\Controllers\Api\ProductPreviewController;
use App\Http\Controllers\Api\ShareController;
use App\Http\Controllers\Api\QrController;
use App\Http\Controllers\Api\FriendController;
use App\Http\Controllers\Api\UserController;
use App\Http\Controllers\Api\InviteController;
use App\Http\Controllers\Api\NotificationSettingController;
use App\Http\Controllers\Api\ProfileAvatarController;
use App\Http\Controllers\Api\ProfileController;
use App\Http\Controllers\Api\SocialAuthController;
use App\Http\Controllers\Api\WishCommentController;
use App\Http\Controllers\Api\WishLikeController;
use App\Http\Controllers\Api\WishClaimController;
use App\Http\Controllers\Api\WishImageController;
use App\Http\Controllers\Api\AppNotificationController;
use App\Http\Controllers\Api\BottomNavBadgeController;

Route::domain(env('APP_DOMAIN_API'))
    ->middleware(['api', 'api.segment'])
    ->group(function () {
        Route::get('/health', HealthController::class)->name('api.health');

        // Временный отладочный эндпойнт для проверки расширения Redis в веб-окружении
        Route::get('/debug/redis', function () {
            return response()->json([
                'extension_loaded' => extension_loaded('redis'),
                'client' => config('database.redis.client'),
                'php_version' => PHP_VERSION,
                'sapi' => php_sapi_name(),
            ]);
        })->name('api.debug.redis');

        // Аутентификация (Sanctum)
        Route::post('/auth/register', [AuthController::class, 'register'])->name('api.auth.register');
        Route::get('/auth/username/check', [AuthController::class, 'checkUsername'])->name('api.auth.username.check');
        Route::post('/auth/login', [AuthController::class, 'login'])->name('api.auth.login');
        Route::post('/auth/vk', [SocialAuthController::class, 'vk'])
            ->middleware('throttle:10,1');
        Route::post('/auth/yandex', [SocialAuthController::class, 'yandex'])
            ->middleware('throttle:10,1');

        // Resolve share-ссылки (доступно без авторизации)
        Route::get('/share/resolve/{token}', [ShareController::class, 'resolve'])->name('api.share.resolve');

        Route::middleware('auth:sanctum')->group(function () {
            Route::get('/auth/me', [AuthController::class, 'me'])->name('api.auth.me');
            Route::post('/auth/logout', [AuthController::class, 'logout'])->name('api.auth.logout');
            Route::post('/auth/logout-all', [AuthController::class, 'logoutAll'])->name('api.auth.logout_all');

            // Профиль текущего пользователя
            Route::patch('/profile', [ProfileController::class, 'update'])->name('api.profile.update');
            Route::post('/profile/avatar', [ProfileAvatarController::class, 'store'])->name('api.profile.avatar.store');
            Route::delete('/profile/avatar', [ProfileAvatarController::class, 'destroy'])->name('api.profile.avatar.destroy');

            Route::post('/products/preview', ProductPreviewController::class)->name('api.products.preview');

            // Настройки уведомлений
            Route::get('/notification-settings', [NotificationSettingController::class, 'show'])
                ->name('api.notification_settings.show');
            Route::put('/notification-settings', [NotificationSettingController::class, 'update'])
                ->name('api.notification_settings.update');

            // Друзья и заявки в друзья
            Route::get('/friends', [FriendController::class, 'index'])->name('api.friends.index');
            Route::delete('/friends/{friend}', [FriendController::class, 'destroy'])->name('api.friends.destroy');

            // Новый неймспейс friend-requests по спецификации API_FRIENDS.md
            Route::post('/friend-requests', [FriendController::class, 'sendRequest'])->name('api.friend_requests.store');
            Route::get('/friend-requests/incoming', [FriendController::class, 'incoming'])->name('api.friend_requests.incoming');
            Route::get('/friend-requests/outgoing', [FriendController::class, 'outgoing'])->name('api.friend_requests.outgoing');
            Route::post('/friend-requests/{friendship}/accept', [FriendController::class, 'accept'])->name('api.friend_requests.accept');
            Route::post('/friend-requests/{friendship}/decline', [FriendController::class, 'reject'])->name('api.friend_requests.decline');
            Route::delete('/friend-requests/{friendship}', [FriendController::class, 'cancel'])->name('api.friend_requests.cancel');

            // Обратная совместимость со старыми маршрутами /friends/requests
            Route::post('/friends/requests', [FriendController::class, 'sendRequest'])->name('api.friends.requests.send');
            Route::get('/friends/requests/pending', [FriendController::class, 'pending'])->name('api.friends.requests.pending');
            Route::post('/friends/requests/{friendship}/accept', [FriendController::class, 'accept'])->name('api.friends.requests.accept');
            Route::post('/friends/requests/{friendship}/reject', [FriendController::class, 'reject'])->name('api.friends.requests.reject');

            // Поиск пользователей
            Route::get('/users/search', [UserController::class, 'search'])->name('api.users.search');

            // Блокировки пользователей
            Route::post('/users/{user}/block', [UserController::class, 'block'])->name('api.users.block');
            Route::delete('/users/{user}/block', [UserController::class, 'unblock'])->name('api.users.unblock');
            Route::get('/users/blocked', [UserController::class, 'blocked'])->name('api.users.blocked');

            // Приглашения
            Route::post('/invites', [InviteController::class, 'store'])->name('api.invites.store');
            Route::post('/invites/{code}/accept', [InviteController::class, 'accept'])->name('api.invites.accept');

            // FCM токены и тестовое уведомление
            Route::post('/fcm/token', [FcmTokenController::class, 'store'])->name('api.fcm.token.store');
            Route::delete('/fcm/token', [FcmTokenController::class, 'destroy'])->name('api.fcm.token.destroy');
            Route::post('/fcm/test', [FcmTokenController::class, 'test'])->name('api.fcm.test');

            // Уведомления приложения
            Route::get('/notifications', [AppNotificationController::class, 'index'])->name('api.notifications.index');
            Route::get('/notifications/unread-count', [AppNotificationController::class, 'unreadCount'])->name('api.notifications.unread_count');
            Route::post('/notifications/{notification}/read', [AppNotificationController::class, 'markAsRead'])->name('api.notifications.mark_read');
            Route::post('/notifications/read-all', [AppNotificationController::class, 'markAllAsRead'])->name('api.notifications.mark_all_read');
            Route::delete('/notifications', [AppNotificationController::class, 'destroyAll'])->name('api.notifications.destroy_all');
            Route::delete('/notifications/{notification}', [AppNotificationController::class, 'destroy'])->name('api.notifications.destroy');

            // QR-коды для шаринга
            Route::get('/qr/{type}/{id?}.png', QrController::class)->name('api.qr.generate');

            // Списки покупок
            Route::get('/shopping-lists', [ShoppingListController::class, 'index'])->name('api.shopping_lists.index');
            Route::post('/shopping-lists', [ShoppingListController::class, 'store'])->name('api.shopping_lists.store');
            Route::get('/shopping-lists/{shoppingList}', [ShoppingListController::class, 'show'])->name('api.shopping_lists.show');
            Route::patch('/shopping-lists/{shoppingList}', [ShoppingListController::class, 'update'])->name('api.shopping_lists.update');
            Route::delete('/shopping-lists/{shoppingList}', [ShoppingListController::class, 'destroy'])->name('api.shopping_lists.destroy');

            // Участники списков покупок
            Route::get('/shopping-lists/{shoppingList}/participants', [ShoppingListController::class, 'participants'])
                ->name('api.shopping_lists.participants.index');
            Route::post('/shopping-lists/{shoppingList}/participants', [ShoppingListController::class, 'addParticipant'])
                ->name('api.shopping_lists.participants.add');
            Route::delete('/shopping-lists/{shoppingList}/participants/{user}', [ShoppingListController::class, 'removeParticipant'])
                ->name('api.shopping_lists.participants.remove');
            Route::post('/shopping-lists/{shoppingList}/leave', [ShoppingListController::class, 'leave'])
                ->name('api.shopping_lists.leave');

            // Пункты списков покупок
            Route::get('/shopping-lists/{shoppingList}/items', [ShoppingListItemController::class, 'index'])->name('api.shopping_list_items.index');
            Route::post('/shopping-lists/{shoppingList}/items', [ShoppingListItemController::class, 'store'])->name('api.shopping_list_items.store');
            Route::patch('/shopping-lists/{shoppingList}/items/{item}', [ShoppingListItemController::class, 'update'])->name('api.shopping_list_items.update');
            Route::delete('/shopping-lists/{shoppingList}/items/{item}', [ShoppingListItemController::class, 'destroy'])->name('api.shopping_list_items.destroy');
            Route::post('/shopping-lists/{shoppingList}/items/{item}/image', [ShoppingListItemController::class, 'uploadImage'])->name('api.shopping_list_items.image.store');

            // Списки желаний
            Route::get('/wishlists', [WishlistController::class, 'index'])->name('api.wishlists.index');
            Route::post('/wishlists', [WishlistController::class, 'store'])->name('api.wishlists.store');
            Route::get('/wishlists/friends', [WishlistController::class, 'friends'])->name('api.wishlists.friends');
            Route::get('/wishlists/public', [WishlistController::class, 'public'])->name('api.wishlists.public');
            Route::get('/wishlists/{wishlist}', [WishlistController::class, 'show'])->name('api.wishlists.show');
            Route::put('/wishlists/{wishlist}', [WishlistController::class, 'update'])->name('api.wishlists.update');
            Route::patch('/wishlists/{wishlist}', [WishlistController::class, 'update']);
            Route::delete('/wishlists/{wishlist}', [WishlistController::class, 'destroy'])->name('api.wishlists.destroy');

            // Участники списков желаний
            Route::get('/wishlists/{wishlist}/participants', [WishlistController::class, 'participants'])->name('api.wishlists.participants.index');
            Route::post('/wishlists/{wishlist}/participants', [WishlistController::class, 'addParticipant'])->name('api.wishlists.participants.add');
            Route::patch('/wishlists/{wishlist}/participants/{user}', [WishlistController::class, 'updateParticipant'])->name('api.wishlists.participants.update');
            Route::delete('/wishlists/{wishlist}/participants/{user}', [WishlistController::class, 'removeParticipant'])->name('api.wishlists.participants.remove');
            Route::post('/wishlists/{wishlist}/leave', [WishlistController::class, 'leave'])->name('api.wishlists.leave');

            // Желания в списке желаний
            Route::get('/wishlists/{wishlist}/wishes', [WishController::class, 'index'])->name('api.wishes.index');
            Route::post('/wishlists/{wishlist}/wishes', [WishController::class, 'store'])->name('api.wishes.store');
            Route::get('/wishlists/{wishlist}/wishes/{wish}', [WishController::class, 'show'])->name('api.wishes.show');
            Route::put('/wishlists/{wishlist}/wishes/{wish}', [WishController::class, 'update'])->name('api.wishes.update');
            Route::patch('/wishlists/{wishlist}/wishes/{wish}', [WishController::class, 'update']);
            Route::delete('/wishlists/{wishlist}/wishes/{wish}', [WishController::class, 'destroy'])->name('api.wishes.destroy');

            // Списки желаний и желания друзей/публичные (аггрегированные)
            Route::post('/wishes', [WishController::class, 'storeStandalone'])->name('api.wishes.store_standalone');
            Route::patch('/wishes/{wish}', [WishController::class, 'updateStandalone'])->name('api.wishes.update_standalone');
            Route::delete('/wishes/{wish}', [WishController::class, 'destroyStandalone'])->name('api.wishes.destroy_standalone');
            Route::get('/wishes/friends', [WishController::class, 'friends'])->name('api.wishes.friends');
            Route::get('/wishes/public', [WishController::class, 'public'])->name('api.wishes.public');

            // Изображения желаний
            Route::post('/wishes/{wish}/images', [WishImageController::class, 'store'])->name('api.wishes.images.store');
            Route::delete('/wishes/{wish}/images/{index}', [WishImageController::class, 'destroy'])->name('api.wishes.images.destroy');

            // Генерация ссылок для шаринга (новый унифицированный API)
            Route::post('/share/link', [ShareController::class, 'createLink'])->name('api.share.link');
            Route::post('/share/join/{token}', [ShareController::class, 'join'])->name('api.share.join');
            Route::post('/share/copy-wish/{token}', [ShareController::class, 'copyWish'])->name('api.share.copy_wish');
            Route::delete('/share/links/{token}', [ShareController::class, 'revokeLink'])->name('api.share.revoke');

            // Генерация ссылок для шаринга (обратная совместимость)
            Route::post('/wishlists/{wishlist}/share', [ShareController::class, 'wishlist'])->name('api.share.wishlist');
            Route::post('/wishlists/{wishlist}/wishes/{wish}/share', [ShareController::class, 'wish'])->name('api.share.wish');
            Route::post('/shopping-lists/{shoppingList}/share', [ShareController::class, 'shoppingList'])->name('api.share.shopping_list');
            Route::get('/users/me/share', [ShareController::class, 'me'])->name('api.share.me');
            Route::get('/app/share', [ShareController::class, 'app'])->name('api.share.app');

            // Участники конкретного желания
            Route::get('/wishlists/{wishlist}/wishes/{wish}/participants', [WishController::class, 'participants'])->name('api.wishes.participants.index');
            Route::post('/wishlists/{wishlist}/wishes/{wish}/participants', [WishController::class, 'addParticipant'])->name('api.wishes.participants.add');
            Route::delete('/wishlists/{wishlist}/wishes/{wish}/participants/{user}', [WishController::class, 'removeParticipant'])->name('api.wishes.participants.remove');

            // Комментарии к желаниям
            Route::get('/wishes/{wish}/comments', [WishCommentController::class, 'index'])->name('api.wishes.comments.index');
            Route::post('/wishes/{wish}/comments', [WishCommentController::class, 'store'])->name('api.wishes.comments.store');
            Route::patch('/wishes/{wish}/comments/{comment}', [WishCommentController::class, 'update'])->name('api.wishes.comments.update');
            Route::delete('/wishes/{wish}/comments/{comment}', [WishCommentController::class, 'destroy'])->name('api.wishes.comments.destroy');

            // Лайки желаний
            Route::get('/wishes/{wish}/likes', [WishLikeController::class, 'index'])->name('api.wishes.likes.index');
            Route::post('/wishes/{wish}/likes', [WishLikeController::class, 'store'])->name('api.wishes.likes.store');
            Route::delete('/wishes/{wish}/likes', [WishLikeController::class, 'destroy'])->name('api.wishes.likes.destroy');
            Route::post('/wishes/{wish}/likes/toggle', [WishLikeController::class, 'toggle'])->name('api.wishes.likes.toggle');

            // Бронирование желаний (claim)
            Route::get('/wishes/{wish}/claims', [WishClaimController::class, 'index'])->name('api.wishes.claims.index');
            Route::post('/wishes/{wish}/claims', [WishClaimController::class, 'store'])->name('api.wishes.claims.store');
            Route::delete('/wishes/{wish}/claims', [WishClaimController::class, 'destroy'])->name('api.wishes.claims.destroy');

            // Индикаторы bottom navigation bar
            Route::get('/badges', [BottomNavBadgeController::class, 'index'])->name('api.badges.index');
            Route::post('/badges/clear', [BottomNavBadgeController::class, 'clear'])->name('api.badges.clear');
        });
    });
