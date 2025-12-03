<?php

namespace App\Http\Requests\Shopping;

use App\Models\ShoppingList;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateShoppingListRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

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
            'name' => ['sometimes', 'string', 'max:255'],
            'description' => ['sometimes', 'nullable', 'string'],
            'visibility' => ['sometimes', 'string', Rule::in(['personal', 'friends', 'public'])],
            'is_shared' => ['sometimes', 'boolean'],
            'status' => ['sometimes', 'string', Rule::in(ShoppingList::STATUSES)],
            'avatar' => ['sometimes', 'nullable', 'string', 'max:1024'],
            'notifications_enabled' => ['sometimes', 'boolean'],
            'deadline_at' => ['sometimes', 'nullable', 'date'],
            'deadline_date' => ['sometimes', 'nullable', 'date'],
            'event_name' => ['sometimes', 'nullable', 'string', 'max:255'],
            'sort_order' => ['sometimes', 'integer'],
        ];
    }
}
