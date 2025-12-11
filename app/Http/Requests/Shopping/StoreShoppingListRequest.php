<?php

namespace App\Http\Requests\Shopping;

use App\Models\ShoppingList;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreShoppingListRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    /**
     * Подготовка входных данных к валидации.
     */
    protected function prepareForValidation(): void
    {
        $data = $this->all();

        $mapped = [];

        if (array_key_exists('deadline_date', $data) && ! array_key_exists('deadline_at', $data)) {
            $mapped['deadline_at'] = $data['deadline_date'];
        }

        if ($mapped !== []) {
            $this->merge($mapped);
        }
    }

    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'visibility' => ['sometimes', 'string', Rule::in(['personal', 'friends', 'public'])],
            'is_shared' => ['sometimes', 'boolean'],
            'status' => ['sometimes', 'string', Rule::in(ShoppingList::STATUSES)],
            'avatar' => ['nullable', 'string', 'max:1024'],
            'card_color' => ['sometimes', 'nullable', 'string', 'max:9', 'regex:/^#[0-9A-Fa-f]{6}$/'],
            'notifications_enabled' => ['sometimes', 'boolean'],
            'deadline_at' => ['sometimes', 'nullable', 'date'],
            'deadline_date' => ['sometimes', 'nullable', 'date'],
            'event_name' => ['sometimes', 'nullable', 'string', 'max:255'],
            'sort_order' => ['sometimes', 'integer'],
        ];
    }
}
