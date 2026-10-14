<?php

namespace App\Http\Requests\Api;

use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateWishRequest extends FormRequest
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
     * Все поля optional; owner_id изменить через request
     * нельзя — он отсутствует в правилах.
     *
     * @return array<string, ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        return [
            'title' => ['sometimes', 'required', 'string', 'max:100'],
            'description' => ['sometimes', 'nullable', 'string', 'max:10000'],
            'price' => ['sometimes', 'nullable', 'integer', 'min:0'],
            'link' => ['sometimes', 'nullable', 'string', 'url', 'max:2048'],
            'image_url' => ['sometimes', 'nullable', 'string', 'url', 'max:2048'],
            // Поле отсутствует → приоритет не трогаем (старые
            // клиенты его не шлют — сбрасывать в 'normal' нельзя).
            'priority' => ['sometimes', 'string', Rule::in(['later', 'normal', 'high'])],
            // Семантика набора доп.изображений однозначна:
            // поле отсутствует → набор не трогаем; [] → удалить все;
            // […] → полная замена упорядоченного набора (по id;
            // элемент без id/с чужим id = новое изображение).
            // `null` недопустим — не должен означать «очистить».
            'images' => ['sometimes', 'array', 'max:20'],
            'images.*.id' => ['nullable', 'string', 'uuid'],
            'images.*.url' => ['required', 'string', 'url', 'max:2048'],
            // null = разгруппировать желание; не-null — только
            // свой живой список (чужой/удалённый → 422).
            'list_id' => [
                'sometimes',
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
