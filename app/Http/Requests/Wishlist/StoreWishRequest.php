<?php

namespace App\Http\Requests\Wishlist;

use App\Models\Wish;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreWishRequest extends FormRequest
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

        if (array_key_exists('link', $data) && ! array_key_exists('url', $data)) {
            $mapped['url'] = $data['link'];
        }

        if (array_key_exists('categories', $data) && ! array_key_exists('tags', $data)) {
            $mapped['tags'] = $data['categories'];
        }

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
            'visibility' => ['sometimes', 'string', Rule::in(Wish::VISIBILITIES)],
            'images' => ['sometimes', 'array'],
            'images.*' => ['string', 'max:2048'],
            'necessity' => ['sometimes', 'string', Rule::in(Wish::NECESSITIES)],
            'description' => ['sometimes', 'nullable', 'string'],
            'url' => ['sometimes', 'nullable', 'url', 'max:2048'],
            'link' => ['sometimes', 'nullable', 'url', 'max:2048'],
            'desired_price' => ['nullable', 'numeric', 'min:0'],
            'price_min' => ['sometimes', 'nullable', 'numeric', 'min:0'],
            'price_max' => ['sometimes', 'nullable', 'numeric', 'min:0'],
            'priority' => ['sometimes', 'string', Rule::in(Wish::PRIORITIES)],
            'tags' => ['sometimes', 'array'],
            'tags.*' => ['string', 'max:64'],
            'categories' => ['sometimes', 'array'],
            'categories.*' => ['string', 'max:64'],
            'reminder_enabled' => ['sometimes', 'boolean'],
            'reminder_at' => ['sometimes', 'nullable', 'date'],
            'deadline_at' => ['sometimes', 'nullable', 'date'],
            'deadline_date' => ['sometimes', 'nullable', 'date'],
            'status' => ['sometimes', 'string', Rule::in(Wish::STATUSES)],
            'hide_price' => ['sometimes', 'boolean'],
            'allow_claiming' => ['sometimes', 'boolean'],
            'sort_index' => ['sometimes', 'integer', 'min:0'],
            'in_progress' => ['sometimes', 'boolean'],
        ];
    }
}
