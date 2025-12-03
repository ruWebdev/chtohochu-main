<?php

namespace App\Http\Requests\Product;

use Illuminate\Foundation\Http\FormRequest;

class FetchProductPreviewRequest extends FormRequest
{
    /**
     * Разрешить выполнение запроса только аутентифицированным пользователям.
     */
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    /**
     * Подготовка входных данных к валидации.
     *
     * Поддерживает формат { "url": "..." } и { "data": { "url": "..." } }.
     */
    protected function prepareForValidation()
    {
        $payload = $this->all();

        if (! array_key_exists('url', $payload) && isset($payload['data']['url'])) {
            $this->merge([
                'url' => $payload['data']['url'],
            ]);
        }
    }

    /**
     * Правила валидации для получения предпросмотра товара по ссылке.
     */
    public function rules(): array
    {
        return [
            'url' => ['required', 'url', 'max:2048'],
        ];
    }
}
