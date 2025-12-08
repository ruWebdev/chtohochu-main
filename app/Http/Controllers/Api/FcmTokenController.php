<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\FCM\StoreFcmTokenRequest;
use App\Models\DeviceToken;
use App\Services\PushNotificationService;
use Illuminate\Http\Request;

class FcmTokenController extends Controller
{
    public function store(StoreFcmTokenRequest $request)
    {
        $user = $request->user();

        $token = DeviceToken::query()
            ->updateOrCreate(
                ['token' => $request->string('token')],
                [
                    'user_id' => $user->id,
                    'platform' => $request->string('platform'),
                    'last_used_at' => now(),
                ]
            );

        return response()->json([
            'message' => __('fcm.token_saved'),
            'token_id' => $token->id,
        ]);
    }

    public function destroy(Request $request)
    {
        $request->validate([
            'token' => ['required', 'string'],
        ]);

        DeviceToken::query()->where('token', $request->string('token'))->delete();

        return response()->json([
            'message' => __('fcm.token_deleted'),
        ]);
    }

    public function test(Request $request, PushNotificationService $pushNotificationService)
    {
        $user = $request->user();

        $pushNotificationService->sendToUser(
            user: $user,
            title: __('notifications.test_title'),
            body: __('notifications.test_body'),
            data: ['type' => 'test']
        );

        return response()->json([
            'message' => __('notifications.test_sent'),
        ]);
    }
}
