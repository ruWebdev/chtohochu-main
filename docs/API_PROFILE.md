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
