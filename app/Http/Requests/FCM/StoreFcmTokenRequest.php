<?php

namespace App\Http\Requests\FCM;

use Illuminate\Foundation\Http\FormRequest;

class StoreFcmTokenRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'token' => ['required', 'string', 'max:1024'],
            'platform' => ['nullable', 'string', 'max:50'],
        ];
    }
}
