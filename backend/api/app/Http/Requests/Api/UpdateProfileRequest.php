<?php

namespace App\Http\Requests\Api;

use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateProfileRequest extends FormRequest
{
    /**
     * Determine if the user is authorized to make this request.
     */
    public function authorize(): bool
    {
        return true;
    }

    /**
     * Username хранится и сравнивается в нижнем регистре.
     */
    protected function prepareForValidation(): void
    {
        if ($this->has('username') && $this->input('username') !== null) {
            $this->merge(['username' => mb_strtolower(trim((string) $this->input('username')))]);
        }
    }

    /**
     * Get the validation rules that apply to the request.
     *
     * Все поля optional; переданный null очищает nullable-поле.
     *
     * @return array<string, ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        return [
            'name' => ['sometimes', 'nullable', 'string', 'max:100'],
            'username' => [
                'sometimes',
                'nullable',
                'string',
                'regex:/^[a-z0-9_.]{3,20}$/',
                Rule::unique('users', 'username')->ignore($this->user()?->id),
            ],
            'avatar_url' => ['sometimes', 'nullable', 'string', 'url', 'max:2048'],
        ];
    }
}
