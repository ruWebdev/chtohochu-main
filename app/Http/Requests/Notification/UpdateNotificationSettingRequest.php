<?php

namespace App\Http\Requests\Notification;

use Illuminate\Foundation\Http\FormRequest;

class UpdateNotificationSettingRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    public function rules(): array
    {
        return [
            'pushEnabled' => ['sometimes', 'boolean'],
            'friendRequests' => ['sometimes', 'boolean'],
            'wishFulfilled' => ['sometimes', 'boolean'],
            'reminders' => ['sometimes', 'boolean'],
            'newWishes' => ['sometimes', 'boolean'],
        ];
    }
}
