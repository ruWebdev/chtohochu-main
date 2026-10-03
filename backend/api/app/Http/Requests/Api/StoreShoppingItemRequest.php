<?php

namespace App\Http\Requests\Api;

use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Foundation\Http\FormRequest;

class StoreShoppingItemRequest extends FormRequest
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
     * list_id/owner не принимаются — список определяется URL.
     * quantity optional (default 1), is_checked — server default.
     *
     * @return array<string, ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        return [
            'id' => ['sometimes', 'string', 'uuid'],
            'title' => ['required', 'string', 'max:200'],
            'quantity' => ['nullable', 'integer', 'min:1'],
        ];
    }
}
