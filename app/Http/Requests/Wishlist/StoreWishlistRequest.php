<?php

namespace App\Http\Requests\Wishlist;

use App\Models\Wishlist;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreWishlistRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    /**
     * Подготовка входных данных к валидации.
     *
     * Принимает новые имена полей из API и маппит их в внутренние колонки.
     */
    protected function prepareForValidation(): void
    {
        $data = $this->all();

        $mapped = [];

        if (array_key_exists('sort_order', $data) && ! array_key_exists('wishes_sort', $data)) {
            $mapped['wishes_sort'] = $data['sort_order'];
        }

        if (array_key_exists('categories', $data) && ! array_key_exists('tags', $data)) {
            $mapped['tags'] = $data['categories'];
        }

        if (array_key_exists('reminder_date', $data) && ! array_key_exists('reminder_at', $data)) {
            $mapped['reminder_at'] = $data['reminder_date'];
            if (! array_key_exists('reminder_enabled', $data)) {
                $mapped['reminder_enabled'] = true;
            }
        }

        if ($mapped !== []) {
            $this->merge($mapped);
        }
    }

    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:255'],
            'description' => ['sometimes', 'nullable', 'string'],
            'visibility' => ['sometimes', 'string', Rule::in(Wishlist::VISIBILITIES)],
            'status' => ['sometimes', 'string', Rule::in(Wishlist::STATUSES)],
            'avatar' => ['nullable', 'string', 'max:1024'],
            'wishes_sort' => ['sometimes', 'string', Rule::in(Wishlist::WISHES_SORT_OPTIONS)],
            'sort_order' => ['sometimes', 'string', Rule::in(Wishlist::WISHES_SORT_OPTIONS)],
            'tags' => ['sometimes', 'array'],
            'tags.*' => ['string', 'max:64'],
            'categories' => ['sometimes', 'array'],
            'categories.*' => ['string', 'max:64'],
            'reminder_enabled' => ['sometimes', 'boolean'],
            'reminder_at' => ['sometimes', 'nullable', 'date'],
            'reminder_date' => ['sometimes', 'nullable', 'date'],
            'allow_claiming' => ['sometimes', 'boolean'],
            'show_claimers' => ['sometimes', 'boolean'],
        ];
    }
}
