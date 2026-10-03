<?php

namespace App\Http\Requests\Api;

use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Foundation\Http\FormRequest;

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
        ];
    }
}
