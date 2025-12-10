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

        // Мобильный клиент Android отправляет часть полей в camelCase — маппим их в snake_case.
        if (array_key_exists('desiredPrice', $data) && ! array_key_exists('desired_price', $data)) {
            $mapped['desired_price'] = $data['desiredPrice'];
        }

        if (array_key_exists('priceMin', $data) && ! array_key_exists('price_min', $data)) {
            $mapped['price_min'] = $data['priceMin'];
        }

        if (array_key_exists('priceMax', $data) && ! array_key_exists('price_max', $data)) {
            $mapped['price_max'] = $data['priceMax'];
        }

        if (array_key_exists('hidePrice', $data) && ! array_key_exists('hide_price', $data)) {
            $mapped['hide_price'] = $data['hidePrice'];
        }

        if (array_key_exists('allowClaiming', $data) && ! array_key_exists('allow_claiming', $data)) {
            $mapped['allow_claiming'] = $data['allowClaiming'];
        }

        if (array_key_exists('allowComments', $data) && ! array_key_exists('allow_comments', $data)) {
            $mapped['allow_comments'] = $data['allowComments'];
        }

        if (array_key_exists('allowSharing', $data) && ! array_key_exists('allow_sharing', $data)) {
            $mapped['allow_sharing'] = $data['allowSharing'];
        }

        if (array_key_exists('privateNotes', $data) && ! array_key_exists('private_notes', $data)) {
            $mapped['private_notes'] = $data['privateNotes'];
        }

        if (array_key_exists('deadlineDate', $data) && ! array_key_exists('deadline_at', $data)) {
            $mapped['deadline_at'] = $data['deadlineDate'];
        }

        if (array_key_exists('sortIndex', $data) && ! array_key_exists('sort_index', $data)) {
            $mapped['sort_index'] = $data['sortIndex'];
        }

        if (array_key_exists('purchaseReceipt', $data) && ! array_key_exists('purchase_receipt', $data)) {
            $mapped['purchase_receipt'] = $data['purchaseReceipt'];
        }

        if (array_key_exists('purchaseDate', $data) && ! array_key_exists('purchase_date', $data)) {
            $mapped['purchase_date'] = $data['purchaseDate'];
        }

        if (array_key_exists('inProgress', $data) && ! array_key_exists('in_progress', $data)) {
            $mapped['in_progress'] = $data['inProgress'];
        }

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
