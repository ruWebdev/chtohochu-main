<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Product\FetchProductPreviewRequest;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;

class ProductPreviewController extends Controller
{
    /**
     * Получение предпросмотра товара по ссылке из маркетплейса.
     */
    public function __invoke(FetchProductPreviewRequest $request)
    {
        $url = (string) $request->string('url');

        $preview = $this->getOgPreview($url);

        if ($preview === null) {
            return response()->json([
                'message' => __('product.fetch_failed'),
            ], 422);
        }

        if ($preview['title'] === '' && $preview['image'] === '') {
            return response()->json([
                'message' => __('product.metadata_not_found'),
            ], 422);
        }

        return response()->json([
            'data' => [
                'name' => $preview['title'] !== '' ? $preview['title'] : $preview['url'],
                'image_url' => $preview['image'] !== '' ? $preview['image'] : null,
                'url' => $preview['url'],
                'description' => $preview['description'],
            ],
        ]);
    }

    private function getOgPreview(string $url): ?array
    {
        $cacheKey = 'og_preview_' . md5($url);

        return Cache::remember($cacheKey, 60 * 60 * 24, function () use ($url) {
            $html = $this->fetchHtml($url);

            if (! $html) {
                return null;
            }

            return $this->parseOgTags($html, $url);
        });
    }

    private function fetchHtml(string $url): ?string
    {
        try {
            $response = Http::withHeaders([
                'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117 Safari/537.36',
            ])
                ->timeout(10)
                ->connectTimeout(5)
                ->withoutVerifying()
                ->get($url);

            if (! $response->successful()) {
                return null;
            }

            // Ограничение размера, чтобы не скачать случайно 50MB
            if (strlen($response->body()) > 2_000_000) { // 2MB
                return null;
            }

            return $response->body();
        } catch (\Throwable $e) {
            return null;
        }
    }

    private function parseOgTags(string $html, string $sourceUrl): array
    {
        $dom = new \DOMDocument();
        $previous = libxml_use_internal_errors(true);

        $dom->loadHTML($html);

        libxml_clear_errors();
        libxml_use_internal_errors($previous);

        $xpath = new \DOMXPath($dom);

        $url = $this->getOg($xpath, 'og:url', $sourceUrl);
        $title = $this->getOg($xpath, 'og:title') ?? '';
        $description = $this->getOg($xpath, 'og:description') ?? '';
        $image = $this->getOg($xpath, 'og:image') ?? '';

        // Fallback: title
        if ($title === '') {
            $titleNodes = $dom->getElementsByTagName('title');
            if ($titleNodes->length > 0) {
                $title = trim((string) $titleNodes->item(0)->textContent);
            }
        }

        // Fallback: description
        if ($description === '') {
            $metaDescriptionNodes = $xpath->query('//meta[@name="description"]/@content');
            if ($metaDescriptionNodes !== false && $metaDescriptionNodes->length > 0) {
                $description = trim((string) $metaDescriptionNodes->item(0)->nodeValue);
            }
        }

        // Приводим URL изображения к абсолютному
        if ($image !== '' && ! str_starts_with($image, 'http')) {
            $image = $this->makeAbsoluteUrl($image, $sourceUrl);
        }

        return [
            'url' => $url,
            'title' => $title,
            'description' => $description,
            'image' => $image,
        ];
    }

    private function getOg(\DOMXPath $xpath, string $property, ?string $fallback = null): ?string
    {
        $query = sprintf('//meta[@property="%s"]/@content', $property);

        $nodes = $xpath->query($query);

        if ($nodes !== false && $nodes->length > 0) {
            $value = trim((string) $nodes->item(0)->nodeValue);
            if ($value !== '') {
                return $value;
            }
        }

        return $fallback;
    }

    private function makeAbsoluteUrl(string $imageUrl, string $pageUrl): string
    {
        $parsedPage = parse_url($pageUrl);

        $scheme = $parsedPage['scheme'] ?? 'https';
        $host = $parsedPage['host'] ?? '';

        if (str_starts_with($imageUrl, '//')) {
            return $scheme . ':' . $imageUrl;
        }

        if (str_starts_with($imageUrl, '/')) {
            return $scheme . '://' . $host . $imageUrl;
        }

        return $imageUrl; // уже нормальная
    }
}
