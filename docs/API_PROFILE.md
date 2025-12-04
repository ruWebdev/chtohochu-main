# PROFILE_API

## POST /profile/avatar

Загрузка и обновление аватара текущего пользователя.

- **Метод:** `POST`
- **URL:** `/profile/avatar`
- **Аутентификация:** Sanctum token (как для `/auth/me`)
- **Контент‑тип:** `multipart/form-data`

### Параметры запроса

- `avatar` — **обязательный**, `file`
  - Обрезанное квадратное изображение аватара
  - Рекомендуемый формат: JPEG/PNG
- `source` — *опциональный*, `string`
  - Источник изображения: `"camera"` или `"gallery"`

### Пример запроса (cURL)

```bash
curl -X POST "https://api.chtohochu.ru/api/profile/avatar" \
  -H "Authorization: Bearer {TOKEN}" \
  -F "avatar=@/path/to/avatar.jpg" \
  -F "source=camera"
```

### Ответ 200 OK

```json
{
  "user": {
    "id": "string",
    "name": "string",
    "email": "string",
    "avatar": "https://cdn.example.com/avatars/12345.jpg",
    "email_verified_at": "2025-01-01T00:00:00Z",
    "created_at": "2025-01-01T00:00:00Z",
    "updated_at": "2025-01-01T00:00:00Z",
    "statistics": {
      "wishes_total": 0,
      "wishes_fulfilled": 0,
      "friends_total": 0
    }
  }
}
```

### Коды ошибок

- `401` — неавторизован (нет или неверный токен)
- `422` — ошибка валидации (нет файла `avatar` или неподдерживаемый формат)
- `500` — внутренняя ошибка сервера

---

## DELETE /profile/avatar

Удаление текущего аватара пользователя (возврат к состоянию без фото).

- **Метод:** `DELETE`
- **URL:** `/profile/avatar`
- **Аутентификация:** Sanctum token

### Пример запроса (cURL)

```bash
curl -X DELETE "https://api.chtohochu.ru/api/profile/avatar" \
  -H "Authorization: Bearer {TOKEN}"
```

### Ответ 200 OK

```json
{
  "user": {
    "id": "string",
    "name": "string",
    "email": "string",
    "avatar": null,
    "email_verified_at": "2025-01-01T00:00:00Z",
    "created_at": "2025-01-01T00:00:00Z",
    "updated_at": "2025-01-01T00:00:00Z",
    "statistics": {
      "wishes_total": 0,
      "wishes_fulfilled": 0,
      "friends_total": 0
    }
  }
}
```

### Коды ошибок

- `401` — неавторизован
- `500` — внутренняя ошибка сервера

---

## PATCH /profile

Обновление профиля текущего пользователя.

- **Метод:** `PATCH`
- **URL:** `/profile`
- **Аутентификация:** Sanctum token

### Тело запроса

Все поля опциональные. Передаются только те, которые нужно изменить.

```json
{
  "username": "string (6-20, уникальный, только a-z 0-9 _)",
  "password": "string, минимум 8 символов",
  "name": "string|null",
  "about": "string|null (до 70 символов)",
  "gender": "male|female|other|null",
  "age": 25,
  "birth_date": "2025-01-01" // формат ISO 8601 на бэкенде
}
```

На клиенте дата рождения вводится в формате `ДД.ММ.ГГГГ` и должна быть преобразована в формат даты, ожидаемый Laravel (например, `Y-m-d`).

### Ответ 200 OK

```json
{
  "user": {
    "id": "string",
    "name": "string",
    "username": "string",
    "email": "string",
    "avatar": "string|null",
    "about": "string|null",
    "gender": "male|female|other|null",
    "age": 25,
    "birth_date": "2025-01-01",
    "email_verified_at": "string|null",
    "created_at": "string",
    "updated_at": "string",
    "statistics": {
      "wishes_total": 0,
      "wishes_fulfilled": 0,
      "friends_total": 0
    }
  }
}
```

### Коды ошибок

- `401` — неавторизован
- `422` — ошибка валидации (например, username занят, неверный формат даты, слишком короткий пароль)
- `500` — внутренняя ошибка сервера

### Рекомендации по реализации на Laravel

- Расширить модель `User` и миграции полями:

```php
Schema::table('users', function (Blueprint $table) {
    $table->string('username')->unique()->change(); // если ещё не уникальный
    $table->string('about', 70)->nullable();
    $table->enum('gender', ['male', 'female', 'other'])->nullable();
    $table->unsignedTinyInteger('age')->nullable();
    $table->date('birth_date')->nullable();
});
```

- Валидация в контроллере профиля (например, `ProfileController@update`):

```php
$userId = $request->user()->id;

$data = $request->validate([
    'username'   => ['sometimes', 'required', 'string', 'min:6', 'max:20', 'regex:/^[a-z0-9_]+$/', 'unique:users,username,' . $userId],
    'password'   => ['sometimes', 'required', 'string', 'min:8'],
    'name'       => ['sometimes', 'nullable', 'string', 'max:255'],
    'about'      => ['sometimes', 'nullable', 'string', 'max:70'],
    'gender'     => ['sometimes', 'nullable', 'in:male,female,other'],
    'age'        => ['sometimes', 'nullable', 'integer', 'min:1', 'max:120'],
    'birth_date' => ['sometimes', 'nullable', 'date'],
]);
```

- Обновление пользователя:

```php
if (isset($data['username'])) {
    $data['username'] = strtolower($data['username']);
}

if (isset($data['password'])) {
    $data['password'] = Hash::make($data['password']);
}

$user->fill($data);
$user->save();

return response()->json([
    'user' => $user->fresh(),
]);
```
