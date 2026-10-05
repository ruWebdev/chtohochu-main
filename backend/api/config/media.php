<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Media upload policy (ADR-015)
    |--------------------------------------------------------------------------
    |
    | purpose → filesystem disk + корневой object-key prefix. Один
    | физический bucket на все purpose; разделение — только prefix'ами.
    | Клиент никогда не выбирает bucket/object key — только backend.
    |
    */

    'purposes' => [
        // Один физический bucket, три корневых object-key prefix'а
        // (ADR-015). `key_prefix` жёстко привязан к purpose — любой
        // ключ ЧтоХочу начинается с `chtohochu-*`, чужие namespaces
        // и корень bucket недостижимы через API.
        'avatar' => [
            'disk' => 'media_avatars',
            // chtohochu-avatars/users/{userId}/avatar/{imageId}.{ext}
            'key_prefix' => 'chtohochu-avatars/',
            'key_pattern' => 'users/%s/avatar/%s.%s',
            'entity_required' => false,
        ],
        'wish' => [
            'disk' => 'media_wish_images',
            // chtohochu-wish-images/users/{userId}/wishes/{entityId}/{imageId}.{ext}
            'key_prefix' => 'chtohochu-wish-images/',
            'key_pattern' => 'users/%s/wishes/%s/%s.%s',
            'entity_required' => true,
        ],
        'shopping' => [
            'disk' => 'media_shopping_images',
            // chtohochu-shopping-images/users/{userId}/shopping-lists/{entityId}/{imageId}.{ext}
            'key_prefix' => 'chtohochu-shopping-images/',
            'key_pattern' => 'users/%s/shopping-lists/%s/%s.%s',
            'entity_required' => true,
        ],
    ],

    // Whitelist допустимых типов контента для presigned PUT.
    'allowed_content_types' => [
        'image/jpeg',
        'image/png',
        'image/webp',
    ],

    // MIME → расширение object key.
    'extensions' => [
        'image/jpeg' => 'jpg',
        'image/png' => 'png',
        'image/webp' => 'webp',
    ],

    // TTL presigned URL: короткоживущий upload credential.
    'upload_ttl_minutes' => (int) env('MEDIA_UPLOAD_TTL_MINUTES', 10),

    // Жёсткий лимит размера объекта (байты). Клиентская компрессия —
    // первая линия уменьшения, серверный лимит обязателен.
    'max_upload_bytes' => (int) env('MEDIA_MAX_UPLOAD_BYTES', 5 * 1024 * 1024),

    // Статусы media_uploads.
    'statuses' => [
        'pending',
        'uploading',
        'uploaded',
        'failed',
        'deleted',
    ],

];
