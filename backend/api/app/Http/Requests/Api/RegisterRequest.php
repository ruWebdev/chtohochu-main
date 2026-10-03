<?php

namespace App\Http\Requests\Api;

use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Foundation\Http\FormRequest;

class RegisterRequest extends FormRequest
{
    /**
     * Determine if the user is authorized to make this request.
     */
    public function authorize(): bool
    {
        return true;
    }

    /**
     * Нормализация до валидации: регистронезависимое сравнение
     * достигается хранением в нижнем регистре.
     */
    protected function prepareForValidation(): void
    {
        $normalized = [];

        if ($this->has('email')) {
            $normalized['email'] = mb_strtolower(trim((string) $this->input('email')));
        }
        if ($this->has('username') && $this->input('username') !== null) {
            $normalized['username'] = mb_strtolower(trim((string) $this->input('username')));
        }

        if ($normalized !== []) {
            $this->merge($normalized);
        }
    }

    /**
     * Get the validation rules that apply to the request.
     *
     * @return array<string, ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        return [
            'email' => ['required', 'string', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
            'name' => ['nullable', 'string', 'max:100'],
            'username' => ['nullable', 'string', 'regex:/^[a-z0-9_.]{3,20}$/', 'unique:users,username'],
        ];
    }
}
