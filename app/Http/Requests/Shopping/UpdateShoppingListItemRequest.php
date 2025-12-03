<?php

namespace App\Http\Requests\Shopping;

use Illuminate\Foundation\Http\FormRequest;

class UpdateShoppingListItemRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    public function rules(): array
    {
        return [
            'name' => ['sometimes', 'string', 'max:255'],
            'image_url' => ['sometimes', 'nullable', 'string', 'max:2048'],
            'quantity' => ['sometimes', 'integer', 'min:1'],
            'unit' => ['sometimes', 'nullable', 'string', 'max:32'],
            'priority' => ['sometimes', 'nullable', 'string', 'max:32'],
            'is_purchased' => ['sometimes', 'boolean'],
            'assigned_user_id' => ['sometimes', 'nullable', 'string', 'exists:users,id'],
            'event_date' => ['sometimes', 'nullable', 'date'],
            'note' => ['sometimes', 'nullable', 'string'],
        ];
    }
}
