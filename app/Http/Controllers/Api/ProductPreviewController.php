<?php

namespace App\Http\Controllers\Api;

use App\Actions\Product\FetchProductPreviewAction;
use App\Http\Controllers\Controller;
use App\Http\Requests\Product\FetchProductPreviewRequest;

class ProductPreviewController extends Controller
{
    /**
     * Получение предпросмотра товара по ссылке из маркетплейса.
     */
    public function __invoke(FetchProductPreviewRequest $request, FetchProductPreviewAction $action)
    {
        try {
            $result = $action->execute($request->string('url'));
        } catch (\RuntimeException $e) {
            $key = $e->getMessage();

            if (! in_array($key, [
                'product.fetch_failed',
                'product.metadata_not_found',
                'product.image_download_failed',
            ], true)) {
                $key = 'product.fetch_failed';
            }

            return response()->json([
                'message' => __($key),
            ], 422);
        } catch (\Throwable $e) {
            return response()->json([
                'message' => __('product.fetch_failed'),
            ], 422);
        }

        return response()->json([
            'data' => $result,
        ]);
    }
}
