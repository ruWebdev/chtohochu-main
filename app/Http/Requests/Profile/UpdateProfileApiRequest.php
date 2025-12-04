<?php

namespace App\Http\Requests\Profile;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateProfileApiRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        $userId = $this->user()?->id;

        return [
            'username' => [
                'sometimes',
                'required',
                'string',
                'min:6',
                'max:20',
                'regex:/^[a-z0-9_]+$/',
                Rule::unique('users', 'username')->ignore($userId),
            ],
            'password' => ['sometimes', 'required', 'string', 'min:8'],
            'name' => ['sometimes', 'nullable', 'string', 'max:255'],
            'about' => ['sometimes', 'nullable', 'string', 'max:70'],
            'gender' => ['sometimes', 'nullable', 'in:male,female,other'],
            'age' => ['sometimes', 'nullable', 'integer', 'min:1', 'max:120'],
            'birth_date' => ['sometimes', 'nullable', 'date'],
        ];
    }
}
