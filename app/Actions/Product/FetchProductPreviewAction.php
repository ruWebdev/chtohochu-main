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
     * Загрузка HTML по ссылке.
     */
    protected function loadHtml(string $url): string
    {
        try {
            $response = Http::withHeaders([
                'User-Agent' => 'Mozilla/5.0 (compatible; chtohochu-bot/1.0; +https://' . config('app.url') . ')',
                'Accept-Language' => 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7',
            ])->timeout(10)->get($url);
        } catch (\Throwable $e) {
            throw new \RuntimeException('product.fetch_failed', 0, $e);
        }

        if (! $response->successful()) {
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

    /**
     * Скачивание изображения и сохранение в публичном хранилище.
     */
    protected function downloadImage(string $imageUrl): string
    {
        try {
            $response = Http::withHeaders([
                'User-Agent' => 'Mozilla/5.0 (compatible; chtohochu-bot/1.0; +https://' . config('app.url') . ')',
            ])->timeout(15)->get($imageUrl);
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
