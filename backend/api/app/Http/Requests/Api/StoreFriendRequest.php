<?php

namespace App\Http\Requests\Api;

use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreFriendRequest extends FormRequest
{
    /**
     * Determine if the user is authorized to make this request.
     */
    public function authorize(): bool
    {
        return true;
    }

    /**
     * Get the validation rules that apply to the request.
     *
     * Второй участник дружбы — всегда auth user; из тела
     * принимаем только id того, кого добавляем.
     *
     * @return array<string, ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        return [
            'user_id' => [
                'required',
                'string',
                'uuid',
                Rule::exists('users', 'id'),
                Rule::notIn([$this->user()?->id]), // нельзя добавить себя
            ],
        ];
    }
}
