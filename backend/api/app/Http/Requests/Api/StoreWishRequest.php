<?php

namespace App\Http\Requests\Api;

use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreWishRequest extends FormRequest
{
    /**
     * Determine if the user is authorized to make this request.
     */
    public function authorize(): bool
    {
        return true;
    }

    /**
     * Get the validation rules that apply to the request.
     *
     * owner_id отсутствует в правилах намеренно: владелец
     * назначается backend из auth()->id(), а не клиентом.
     *
     * @return array<string, ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        return [
            'id' => ['sometimes', 'string', 'uuid'],
            'title' => ['required', 'string', 'max:100'],
            'description' => ['nullable', 'string', 'max:10000'],
            'price' => ['nullable', 'integer', 'min:0'],
            'link' => ['nullable', 'string', 'url', 'max:2048'],
            'image_url' => ['nullable', 'string', 'url', 'max:2048'],
            // Приоритет желания; отсутствие = 'normal' (default БД).
            'priority' => ['sometimes', 'string', Rule::in(['later', 'normal', 'high'])],
            // Дополнительные изображения (primary — image_url).
            // Отсутствие поля / null = без доп.изображений; массив —
            // упорядоченный набор (индекс → sort_order). `id` —
            // клиентский UUID = client_id media upload.
            'images' => ['nullable', 'array', 'max:20'],
            'images.*.id' => ['nullable', 'string', 'uuid'],
            'images.*.url' => ['required', 'string', 'url', 'max:2048'],
            // Membership: только СВОЙ живой список желаний —
            // чужой/удалённый list_id отклоняется (422).
            'list_id' => [
                'nullable',
                'string',
                'uuid',
                Rule::exists('wish_lists', 'id')->where(
                    fn ($q) => $q
                        ->where('owner_id', $this->user()->id)
                        ->whereNull('deleted_at'),
                ),
            ],
        ];
    }
}
