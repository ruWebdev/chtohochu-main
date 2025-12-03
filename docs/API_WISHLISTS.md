# API списков желаний (Laravel 12 + Sanctum)

Документ описывает REST‑эндпойнты, которые используются текущим мобильным приложением для работы **со списками желаний** и **желаниями**.

Базовый URL (dev): `http://10.0.2.2:8082/api`

Все защищённые запросы требуют Sanctum‑токен в заголовке:

```http
Authorization: Bearer {token}
Accept: application/json
```

---

## 1. Списки желаний (мои)

### 1.1. Получить все списки желаний

`GET /wishlists`

**Параметры query (опционально):**
- `status` — статус списка (`new`, `in_progress`, `closed` или массив этих значений).
- `visibility` — видимость (`personal`, `friends`, `public` или массив).

**Ответ 200:**
```json
{
  "data": [
    {
      "id": "uuid",
      "owner_id": "uuid",
      "owner_name": "Имя владельца",
      "owner_avatar": "https://..." ,
      "name": "ДР Анны",
      "description": "...",
      "visibility": "personal",
      "status": "new",
      "avatar": "🎂",
      "participants": [
        {
          "id": "uuid",
          "name": "Друг",
          "email": "friend@mail.ru",
          "avatar": "https://...",
          "role": "viewer"
        }
      ],
      "sort_order": "priority",
      "categories": ["Подарки", "ДР"],
      "reminder_date": "2025-01-01T00:00:00Z",
      "allow_claiming": true,
      "show_claimers": true,
      "created_at": "2025-01-01T10:00:00Z",
      "updated_at": "2025-01-02T10:00:00Z",
      "wishes": [ /* опционально, массив желаний */ ]
    }
  ]
}
```

Приложение использует этот эндпойнт в полной синхронизации (`WishlistsSync.fullSync`) для обновления локального кеша.

---

### 1.2. Получить один список желаний

`GET /wishlists/{wishlist_id}`

**Ответ 200:**
```json
{
  "data": {
    "id": "uuid",
    "owner_id": "uuid",
    "owner_name": "Имя",
    "owner_avatar": "https://...",
    "name": "Название",
    "description": "Описание",
    "visibility": "personal",
    "status": "new",
    "avatar": "🎁",
    "participants": [ /* см. выше */ ],
    "sort_order": "priority",
    "categories": ["Подарки"],
    "reminder_date": null,
    "allow_claiming": true,
    "show_claimers": true,
    "created_at": "...",
    "updated_at": "...",
    "wishes": [ /* список желаний */ ]
  }
}
```

Используется при детальных сценариях (при необходимости обновить один список).

---

### 1.3. Создать список желаний

`POST /wishlists`

**Тело запроса (CreateWishlistRequest):**
```json
{
  "name": "Новый список",
  "description": "Описание",
  "visibility": "personal",      // опционально
  "status": "new",               // опционально
  "avatar": "🎁",                // эмодзи или URL
  "sort_order": "priority",      // опционально
  "categories": ["Подарки"],
  "reminder_date": "2025-01-01T00:00:00Z", // опционально
  "allow_claiming": true,
  "show_claimers": true
}
```

**Ответ 201:**
```json
{
  "data": { /* WishlistApi как в GET /wishlists/{id} */ }
}
```

В приложении обёрнуто в `WishlistsSync.createWishlist` с optimistic update: сначала создаётся локальный список (`WishlistLocal`), затем отправляется запрос на сервер.

---

### 1.4. Обновить список желаний

`PATCH /wishlists/{wishlist_id}`

**Тело запроса (UpdateWishlistRequest, все поля опциональны):**
```json
{
  "name": "Новое имя",
  "description": "Новый текст",
  "visibility": "friends",
  "status": "in_progress",
  "avatar": "🎂",
  "sort_order": "created_at",
  "categories": ["ДР", "Праздник"],
  "reminder_date": "2025-02-01T00:00:00Z",
  "allow_claiming": true,
  "show_claimers": false
}
```

**Ответ 200:**
```json
{
  "data": { /* обновлённый WishlistApi */ }
}
```

Используется в `WishlistsSync.updateWishlist` и при обработке очереди синхронизации.

---

### 1.5. Удалить список желаний

`DELETE /wishlists/{wishlist_id}`

**Ответ 204 / 200:** без тела или с сообщением.

В UI используется через `WishlistsSync.deleteWishlist`:
- сначала локально помечает/удаляет список,
- затем добавляет операцию в очередь синхронизации,
- при обработке очереди вызывает этот эндпойнт.

---

## 2. Списки желаний друзей и публичные

### 2.1. Списки желаний друзей

`GET /wishlists/friends`

**Параметры query (опционально):**
- `status` — как в `/wishlists`;
- `visibility` — `friends`, `public` или массив этих значений.

**Ответ 200:**
```json
{
  "data": [ /* WishlistApi */ ]
}
```

Используется в `WishlistsSync.syncFriendsAndPublic` для обновления кеша друзей.

---

### 2.2. Публичные списки желаний

`GET /wishlists/public`

**Параметры query (опционально):**
- `status` — как в `/wishlists`.

**Ответ 200:**
```json
{
  "data": [ /* WishlistApi */ ]
}
```

Также используется в `WishlistsSync.syncFriendsAndPublic` для кеша публичных списков.

---

## 3. Участники списков желаний

### 3.1. Получить участников списка

`GET /wishlists/{wishlist_id}/participants`

**Ответ 200:**
```json
{
  "data": [
    {
      "id": "uuid",
      "name": "Имя",
      "email": "user@mail.ru",
      "avatar": "https://...",
      "role": "viewer" // или editor/admin
    }
  ]
}
```

### 3.2. Добавить участника в список

`POST /wishlists/{wishlist_id}/participants`

**Тело запроса:**
```json
{
  "user_id": "uuid"
}
```

**Ответ 200:**
```json
{
  "data": { /* обновлённый WishlistApi */ }
}
```

### 3.3. Удалить участника из списка

`DELETE /wishlists/{wishlist_id}/participants/{user_id}`

**Ответ:** 204 / 200 без тела.

---

## 4. Желания внутри списка

### 4.1. Получить все желания списка

`GET /wishlists/{wishlist_id}/wishes`

**Параметры query (опционально):**
- `status` — статус желания (`fulfilled`, `not_fulfilled`, `in_progress`);
- `visibility` — видимость (`personal`, `friends`, `public`);
- `necessity` — приоритет по важности (`later`, `need`, `urgent`).

**Ответ 200:**
```json
{
  "data": [
    {
      "id": "uuid",
      "wishlist_id": "uuid",
      "name": "Название желания",
      "description": "Описание",
      "visibility": "personal",
      "images": ["https://..."],
      "link": "https://...",
      "necessity": "later",
      "priority": "medium",
      "desired_price": "1000.00",
      "price_min": "500.00",
      "price_max": "1500.00",
      "hide_price": false,
      "categories": ["Гаджеты"],
      "status": "not_fulfilled",
      "in_progress": false,
      "claimers": [
        {
          "id": "uuid",
          "name": "Друг",
          "avatar": "https://...",
          "claimed_at": "2025-01-01T00:00:00Z",
          "is_secret": false
        }
      ],
      "allow_claiming": true,
      "deadline_date": null,
      "sort_index": 1,
      "created_at": "...",
      "updated_at": "..."
    }
  ]
}
```

### 4.2. Получить одно желание

`GET /wishlists/{wishlist_id}/wishes/{wish_id}`

**Ответ 200:**
```json
{
  "data": { /* WishApi как выше */ }
}
```

### 4.3. Создать желание в списке

`POST /wishlists/{wishlist_id}/wishes`

**Тело запроса (CreateWishRequest):**
```json
{
  "name": "Подарок",
  "description": "Описание",
  "visibility": "personal",
  "images": ["https://..."],
  "link": "https://...",
  "necessity": "later",
  "priority": "medium",
  "desired_price": 1000,
  "price_min": 500,
  "price_max": 1500,
  "hide_price": false,
  "categories": ["Гаджеты"],
  "status": "not_fulfilled",
  "allow_claiming": true,
  "deadline_date": "2025-01-01T00:00:00Z",
  "sort_index": 1
}
```

**Ответ 201:**
```json
{
  "data": { /* WishApi */ }
}
```

В мобильном приложении создание желания производится через `WishlistsApi.createWish` (привязано к конкретному списку) или `WishlistsApi.createStandaloneWish` (см. ниже).

---

### 4.4. Обновить желание

`PATCH /wishlists/{wishlist_id}/wishes/{wish_id}`

**Тело запроса (UpdateWishRequest, всё опционально):**
```json
{
  "name": "Новое имя",
  "description": "Новый текст",
  "visibility": "friends",
  "images": ["https://..."],
  "link": "https://...",
  "necessity": "need",
  "priority": "high",
  "desired_price": 1500,
  "price_min": 800,
  "price_max": 2000,
  "hide_price": false,
  "categories": ["Гаджеты"],
  "status": "fulfilled",
  "allow_claiming": true,
  "deadline_date": "2025-02-01T00:00:00Z",
  "sort_index": 2
}
```

**Ответ 200:**
```json
{
  "data": { /* обновлённый WishApi */ }
}
```

### 4.5. Удалить желание

`DELETE /wishlists/{wishlist_id}/wishes/{wish_id}`

**Ответ:** 204 / 200 без тела.

---

## 5. Желания без привязки к списку

### 5.1. Создать standalone‑желание

`POST /wishes`

**Тело (CreateWishRequest):** такое же, как для `POST /wishlists/{id}/wishes`.

**Ответ 201:**
```json
{
  "data": { /* WishApi */ }
}
```

Используется в приложении для создания желаний вне конкретного списка (`WishlistsApi.createStandaloneWish`).

---

## 6. Участники желаний

### 6.1. Получить участников желания

`GET /wishlists/{wishlist_id}/wishes/{wish_id}/participants`

**Ответ 200:**
```json
{
  "data": [
    {
      "id": "uuid",
      "name": "Имя",
      "email": "user@mail.ru",
      "avatar": "https://...",
      "role": "viewer"
    }
  ]
}
```

### 6.2. Добавить участника к желанию

`POST /wishlists/{wishlist_id}/wishes/{wish_id}/participants`

**Тело запроса:**
```json
{
  "user_id": "uuid"
}
```

**Ответ 200:**
```json
{
  "data": [ /* массив WishlistUserApi */ ]
}
```

### 6.3. Удалить участника из желания

`DELETE /wishlists/{wishlist_id}/wishes/{wish_id}/participants/{user_id}`

**Ответ:** 204 / 200 без тела.

---

## 7. Агрегированные желания друзей и публичные

### 7.1. Желания друзей

`GET /wishes/friends`

**Параметры query (опционально):**
- `status` — один или несколько статусов желаний;
- `visibility` — `friends` / `public` или массив;
- `necessity` — один или несколько уровней важности.

**Ответ 200:**
```json
{
  "data": [ /* WishApi */ ]
}
```

Используется в `WishlistsSync.syncFriendsAndPublic` для кеша желаний друзей.

---

### 7.2. Публичные желания

`GET /wishes/public`

**Параметры query (опционально):**
- `status` — статусы желаний;
- `necessity` — уровни важности.

**Ответ 200:**
```json
{
  "data": [ /* WishApi */ ]
}
```

Также используется в `WishlistsSync.syncFriendsAndPublic`.
