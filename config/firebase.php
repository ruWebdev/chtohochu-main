<?php

return [
    'default' => env('FIREBASE_PROJECT', 'app'),

    'projects' => [
        'app' => [
            'credentials' => [
                'file' => env('FIREBASE_CREDENTIALS'), // путь к service account JSON
            ],
            'database' => [
                'url' => env('FIREBASE_DATABASE_URL'),
            ],
            'storage' => [
                'default_bucket' => env('FIREBASE_STORAGE_BUCKET'),
            ],
        ],
    ],
];
