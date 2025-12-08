<?php

namespace App\Actions\Product;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class FetchProductPreviewAction
{
    /**
     * Загрузка страницы товара, извлечение названия и главной картинки,
     * скачивание картинки в локальное хранилище.
     */
    public function execute(string $url): array
    {
        if ($this->isWildberriesUrl($url)) {
            return $this->fetchWildberriesProductViaApi($url);
        }

        $html = $this->loadHtml($url);

        [$name, $imageUrl] = $this->extractMeta($html);

        if (! $imageUrl) {
            throw new \RuntimeException('product.metadata_not_found');
        }

        $storedImageUrl = $this->downloadImage($imageUrl);

        return [
            'name' => $name ?: $url,
            'image_url' => $storedImageUrl,
        ];
    }

    /**
     * Проверка, что ссылка указывает на товар Wildberries.
     */
    protected function isWildberriesUrl(string $url): bool
    {
        $parts = parse_url($url);

        if (! isset($parts['host'], $parts['path'])) {
            return false;
        }

        $host = Str::lower($parts['host']);

        if ($host !== 'www.wildberries.ru' && $host !== 'wildberries.ru') {
            return false;
        }

        return (bool) preg_match('#^/catalog/\\d+/detail\\.aspx#', $parts['path']);
    }

    /**
     * Извлечение артикула (nmId) из ссылки Wildberries.
     */
    protected function extractWildberriesNmId(string $url): ?int
    {
        $parts = parse_url($url);

        if (! isset($parts['path'])) {
            return null;
        }

        if (! preg_match('#^/catalog/(\\d+)/detail\\.aspx#', $parts['path'], $matches)) {
            return null;
        }

        return (int) $matches[1];
    }

    /**
     * Получение названия и изображения товара Wildberries через публичный JSON-API.
     */
    protected function fetchWildberriesProductViaApi(string $url): array
    {
        $nmId = $this->extractWildberriesNmId($url);

        if (! $nmId) {
            throw new \RuntimeException('product.metadata_not_found');
        }

        try {
            $response = Http::timeout(5)
                ->retry(2, 500)
                ->get('https://card.wb.ru/cards/v2/detail', [
                    'appType' => 1,
                    'curr' => 'rub',
                    'dest' => -1257786,
                    'nm' => $nmId,
                ]);
        } catch (\Throwable $e) {
            throw new \RuntimeException('product.fetch_failed', 0, $e);
        }

        if (! $response->successful()) {
            if ($response->status() === 404) {
                throw new \RuntimeException('product.metadata_not_found');
            }

            throw new \RuntimeException('product.fetch_failed');
        }

        $json = $response->json();

        if (
            ! is_array($json)
            || ! isset($json['data']['products'][0])
            || ! is_array($json['data']['products'][0])
        ) {
            throw new \RuntimeException('product.metadata_not_found');
        }

        $product = $json['data']['products'][0];

        $name = isset($product['name']) && is_string($product['name'])
            ? trim($product['name'])
            : null;

        $nmIdFromApi = isset($product['id']) ? (string) $product['id'] : (string) $nmId;

        $imageUrl = $this->buildWildberriesImageUrl($nmIdFromApi);

        if ($imageUrl === '') {
            throw new \RuntimeException('product.metadata_not_found');
        }

        $storedImageUrl = $this->downloadImage($imageUrl);

        return [
            'name' => $name ?: $url,
            'image_url' => $storedImageUrl,
        ];
    }

    /**
     * Загрузка HTML по ссылке.
     */
    protected function loadHtml(string $url): string
    {
        try {
            $response = Http::withHeaders($this->getDefaultHeaders())
                ->timeout(10)
                ->retry(2, 500)
                ->get($url);
        } catch (\Throwable $e) {
            throw new \RuntimeException('product.fetch_failed', 0, $e);
        }

        if (! $response->successful()) {
            if ($response->status() === 404) {
                throw new \RuntimeException('product.metadata_not_found');
            }

            throw new \RuntimeException('product.fetch_failed');
        }

        return (string) $response->body();
    }

    /**
     * Извлечение названия и URL изображения из meta-тегов страницы.
     */
    protected function extractMeta(string $html): array
    {
        $dom = new \DOMDocument();
        $previous = libxml_use_internal_errors(true);

        $dom->loadHTML($html);

        libxml_clear_errors();
        libxml_use_internal_errors($previous);

        $xpath = new \DOMXPath($dom);

        $name = $this->getMetaContent($xpath, [
            ['property' => 'og:title'],
            ['name' => 'og:title'],
            ['property' => 'twitter:title'],
        ]);

        if (! $name) {
            $titleNodeList = $dom->getElementsByTagName('title');
            if ($titleNodeList->length > 0) {
                $name = trim($titleNodeList->item(0)->textContent);
            }
        }

        $imageUrl = $this->getMetaContent($xpath, [
            ['property' => 'og:image'],
            ['name' => 'og:image'],
            ['property' => 'twitter:image'],
        ]);

        return [$name, $imageUrl];
    }

    /**
     * Получение значения content из meta-тегов по списку кандидатов.
     */
    protected function getMetaContent(\DOMXPath $xpath, array $candidates): ?string
    {
        foreach ($candidates as $candidate) {
            if (isset($candidate['property'])) {
                $query = sprintf("//meta[@property='%s']/@content", $candidate['property']);
            } else {
                $query = sprintf("//meta[@name='%s']/@content", $candidate['name']);
            }

            $nodes = $xpath->query($query);

            if ($nodes !== false && $nodes->length > 0) {
                $value = trim((string) $nodes->item(0)->nodeValue);
                if ($value !== '') {
                    return $value;
                }
            }
        }

        return null;
    }

    protected function buildWildberriesImageUrl(string $nmId): string
    {
        $nmId = trim($nmId);

        if ($nmId === '') {
            return '';
        }

        return 'https://images.wbstatic.net/big/new/' . $nmId . '-1.jpg';
    }

    protected function getDefaultHeaders(): array
    {
        return [
            'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
            'Accept-Language' => 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7',
            'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
        ];
    }

    protected function normalizeImageUrl(string $imageUrl): string
    {
        $imageUrl = trim($imageUrl);

        if ($imageUrl === '') {
            return $imageUrl;
        }

        if (Str::startsWith($imageUrl, '//')) {
            return 'https:' . $imageUrl;
        }

        return $imageUrl;
    }

    /**
     * Скачивание изображения и сохранение в публичном хранилище.
     */
    protected function downloadImage(string $imageUrl): string
    {
        $imageUrl = $this->normalizeImageUrl($imageUrl);

        try {
            $response = Http::withHeaders($this->getDefaultHeaders())
                ->timeout(15)
                ->retry(2, 500)
                ->get($imageUrl);
        } catch (\Throwable $e) {
            throw new \RuntimeException('product.image_download_failed', 0, $e);
        }

        if (! $response->successful()) {
            throw new \RuntimeException('product.image_download_failed');
        }

        $path = parse_url($imageUrl, PHP_URL_PATH) ?: '';
        $extension = pathinfo($path, PATHINFO_EXTENSION);

        if (! $extension) {
            $extension = 'jpg';
        }

        $filename = Str::uuid()->toString() . '.' . $extension;
        $storagePath = 'product-previews/' . $filename;

        Storage::disk('public')->put($storagePath, $response->body());

        return Storage::disk('public')->url($storagePath);
    }
}
