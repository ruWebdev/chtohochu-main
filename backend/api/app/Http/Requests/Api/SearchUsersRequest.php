<?php

namespace App\Http\Requests\Api;

use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Foundation\Http\FormRequest;

class SearchUsersRequest extends FormRequest
{
    /**
     * Determine if the user is authorized to make this request.
     */
    public function authorize(): bool
    {
        return true;
    }

    /**
     * Ведущий '@' — поиск по username; до валидации снимаем
     * его, чтобы '@alex' и 'alex' работали одинаково.
     */
    protected function prepareForValidation(): void
    {
        $this->merge(['q' => ltrim(trim((string) $this->query('q', '')), '@')]);
    }

    /**
     * Get the validation rules that apply to the request.
     *
     * @return array<string, ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        return [
            'q' => ['required', 'string', 'min:1', 'max:50'],
        ];
    }
}
