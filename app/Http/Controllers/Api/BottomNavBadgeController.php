<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\BottomNavBadge;
use App\Services\BottomNavBadgeService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

/**
 * Контроллер для управления индикаторами bottom navigation bar.
 */
class BottomNavBadgeController extends Controller
{
    public function __construct(
        private BottomNavBadgeService $badgeService
    ) {}

    /**
     * Получить текущее состояние индикаторов.
     * GET /api/badges
     */
    public function index(Request $request): JsonResponse
    {
        $badges = $this->badgeService->getBadges($request->user()->id);

        return response()->json([
            'success' => true,
            'data' => $badges,
        ]);
    }

    /**
     * Сбросить индикатор при открытии экрана.
     * POST /api/badges/clear
     * 
     * @param Request $request
     * @return JsonResponse
     */
    public function clear(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'screen' => 'required|string|in:' . implode(',', BottomNavBadge::VALID_SCREENS),
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Некорректный идентификатор экрана',
                'errors' => $validator->errors(),
            ], 422);
        }

        $screen = $request->input('screen');
        $this->badgeService->clearBadge($request->user()->id, $screen);

        return response()->json([
            'success' => true,
            'data' => $this->badgeService->getBadges($request->user()->id),
        ]);
    }
}
