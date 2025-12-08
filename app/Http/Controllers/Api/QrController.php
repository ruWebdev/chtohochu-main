<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Endroid\QrCode\Builder\Builder;
use Endroid\QrCode\Writer\PngWriter;
use Illuminate\Http\Request;

class QrController extends Controller
{
    public function __invoke(Request $request, string $type, ?string $id = null)
    {
        $path = $this->buildPath($type, $id);

        $baseUrl = rtrim((string) config('sharing.share_base_url'), '/');
        $targetUrl = $baseUrl . '/' . ltrim($path, '/');

        $result = Builder::create()
            ->writer(new PngWriter())
            ->data($targetUrl)
            ->size(300)
            ->margin(10)
            ->build();

        return response($result->getString(), 200, [
            'Content-Type' => $result->getMimeType(),
            'Cache-Control' => 'public, max-age=31536000',
        ]);
    }

    private function buildPath(string $type, ?string $id): string
    {
        switch ($type) {
            case 'app':
                return 'app';
            case 'wishlist':
            case 'wish':
            case 'shopping-list':
            case 'user':
                if ($id === null || $id === '') {
                    abort(404);
                }

                return $type . '/' . $id;
            default:
                abort(404);
        }
    }
}
