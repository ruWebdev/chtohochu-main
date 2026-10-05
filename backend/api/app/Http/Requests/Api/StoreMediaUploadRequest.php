<?php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreMediaUploadRequest extends FormRequest
{
    /**
     * Whitelist типов и лимит размера — из config/media.php.
     * bucket/object key клиент НЕ передаёт и не может подменить.
     */
    public function rules(): array
    {
        return [
            'purpose' => ['required', Rule::in(array_keys(config('media.purposes')))],
            'entity_id' => ['nullable', 'uuid'],
            'content_type' => ['required', Rule::in(config('media.allowed_content_types'))],
            'size' => ['required', 'integer', 'min:1', 'max:'.config('media.max_upload_bytes')],
            'client_id' => ['nullable', 'uuid'],
        ];
    }
}
