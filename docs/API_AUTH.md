# AUTH API

## POST /auth/register

Регистрация нового пользователя.

### Тело запроса

```json
{
  "username": "string (6-20, уникальный, только a-z 0-9 _)",
  "email": "string, email, уникальный",
  "password": "string, минимум 8 символов"
}
```

### Ответ 201

```json
{
  "user": {
    "id": "string",
    "name": "string",
    "username": "string",
    "email": "string",
    "avatar": "string|null",
    "email_verified_at": "string|null",
    "created_at": "string",
    "updated_at": "string"
  },
  "token": "string"
}
```

### Ошибки

- `422 Unprocessable Entity` — ошибки валидации (Laravel):

```json
{
  "message": "The given data was invalid.",
  "errors": {
    "username": [
      "The username field is required.",
      "The username must be at least 6 characters.",
      "The username format is invalid.",
      "The username has already been taken."
    ],
    "email": ["The email has already been taken."]
  }
}
```


## GET /auth/username/check

Проверка доступности имени пользователя.

### Параметры запроса

- `username` (query) — строка 6–20 символов, только `[a-z0-9_]`, приводится к нижнему регистру.

Пример:

```http
GET /auth/username/check?username=ivan_petrov
```

### Ответ 200

```json
{
  "available": true
}
```

`available = false` означает, что имя уже занято.


## Заметки по реализации на Laravel

- В таблицу `users` добавить колонку `username` с уникальным индексом:

```php
$table->string('username')->unique();
```

- Валидация в `POST /auth/register`:

```php
$request->validate([
    'username' => ['required', 'string', 'min:6', 'max:20', 'regex:/^[a-z0-9_]+$/', 'unique:users,username'],
    'email'    => ['required', 'string', 'email', 'max:255', 'unique:users,email'],
    'password' => ['required', 'string', 'min:8'],
]);
```

- Сохранение пользователя:

```php
$user = User::create([
    'name'     => $request->input('username'), // или отдельное поле name, если нужно
    'username' => strtolower($request->input('username')),
    'email'    => $request->input('email'),
    'password' => Hash::make($request->input('password')),
]);
```

- `GET /auth/username/check`:

```php
public function checkUsername(Request $request)
{
    $request->validate([
        'username' => ['required', 'string', 'min:6', 'max:20', 'regex:/^[a-z0-9_]+$/'],
    ]);

    $username = strtolower($request->input('username'));
    $exists = User::where('username', $username)->exists();

    return response()->json([
        'available' => !$exists,
    ]);
}
```

