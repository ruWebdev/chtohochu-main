# API: Аутентификация (Sanctum) и FCM

Ниже — минимальные шаги для мобильных/SPA клиентов, чтобы быстро начать работу с API.

## 1) Установка и миграции (для бэкенда)

Выполните команды:

```bash
composer require kreait/laravel-firebase:^4.3 laravel-notification-channels/fcm:^5.3
php artisan vendor:publish --provider="Laravel\Sanctum\SanctumServiceProvider" --tag="sanctum-migrations"
php artisan migrate
```

Добавьте переменные окружения в `.env`:

```
# Домен API (используется в маршрутах API)
APP_DOMAIN_API=api.example.com

# Firebase
FIREBASE_PROJECT=app
FIREBASE_CREDENTIALS=/absolute/path/to/firebase-service-account.json
FIREBASE_DATABASE_URL=
FIREBASE_STORAGE_BUCKET=
```

Если нужно, опубликуйте конфиг Firebase:

```bash
php artisan vendor:publish --provider="Kreait\\Laravel\\Firebase\\ServiceProvider" --tag=config
```

## 2) Эндпоинты аутентификации

Базовый URL (пример): `https://{APP_DOMAIN_API}`

- POST `/auth/register`
  - Тело: `{ name: string, email: string, password: string }`
  - Ответ: `{ user: {...}, token: string }`

- POST `/auth/login`
  - Тело: `{ email: string, password: string }`
  - Ответ: `{ user: {...}, token: string }`

- GET `/auth/me` (требуется заголовок `Authorization: Bearer {token}`)
  - Ответ: `{ user: {...} }`

- POST `/auth/logout` (Bearer токен)
  - Ответ: `{ message: string }`

- POST `/auth/logout-all` (Bearer токен)
  - Ответ: `{ message: string }`

Примечания:
- Авторизация — через заголовок `Authorization: Bearer {token}` (Sanctum personal access token).
- Лимит попыток входа настроен через стандартный `LoginRequest`.

## 3) FCM: регистрация токенов устройств

- POST `/fcm/token` (Bearer токен)
  - Тело: `{ token: string, platform?: string }`
  - Ответ: `{ message: string, token_id: string }`

- DELETE `/fcm/token` (Bearer токен)
  - Тело: `{ token: string }`
  - Ответ: `{ message: string }`

- POST `/fcm/test` (Bearer токен)
  - Отправляет тестовое push-уведомление текущему пользователю на все его зарегистрированные токены.
  - Ответ: `{ message: string }`

Модель `DeviceToken` хранит токены устройств (UUID, внешний ключ на `users`). Пользовательский метод `routeNotificationForFcm()` возвращает массив токенов для канала `fcm`.

## 4) Примеры запросов (cURL)

1) Регистрация и получение токена:
```bash
curl -X POST https://api.example.com/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"name":"Ivan","email":"ivan@example.com","password":"secret-Password1"}'
```

2) Логин:
```bash
curl -X POST https://api.example.com/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"ivan@example.com","password":"secret-Password1"}'
```

3) Получить профиль:
```bash
curl -X GET https://api.example.com/auth/me \
  -H 'Authorization: Bearer {TOKEN}'
```

4) Сохранить FCM-токен:
```bash
curl -X POST https://api.example.com/fcm/token \
  -H 'Authorization: Bearer {TOKEN}' \
  -H 'Content-Type: application/json' \
  -d '{"token":"<FCM-TOKEN>","platform":"android"}'
```

5) Удалить FCM-токен:
```bash
curl -X DELETE https://api.example.com/fcm/token \
  -H 'Authorization: Bearer {TOKEN}' \
  -H 'Content-Type: application/json' \
  -d '{"token":"<FCM-TOKEN>"}'
```

6) Отправить тестовый push:
```bash
curl -X POST https://api.example.com/fcm/test \
  -H 'Authorization: Bearer {TOKEN}'
```

## 5) Настройка клиента FCM

- Мобильные приложения: добавьте Google Services (Android: `google-services.json`, iOS: `GoogleService-Info.plist`) и подключите FCM SDK.
- После получения FCM токена на устройстве — отправляйте его на `/fcm/token` после авторизации.
- Рекомендуется обновлять токен при каждом запуске приложения и при событии обновления токена со стороны SDK.

## 6) Коды и локализация

- Сообщения об ошибках/успехе — через `resources/lang/ru/*.php` (`auth.php`, `fcm.php`, `notifications.php`).
- Все новые сущности спроектированы под UUID и соответствуют правилам проекта (Services/Actions, Form Requests, Policies по мере расширения).

## 7) Требования безопасности

- Всегда передавайте токен только по HTTPS.
- Храните токен безопасно (Keychain/Keystore/Secure storage).
- Очищайте токен при логауте.

## 8) Частые проблемы

- 401/Unauthenticated: проверьте заголовок `Authorization: Bearer {token}`.
- 403/CSRF в SPA: для чистого API с Bearer токенами CSRF не нужен; для cookie-based Sanctum — используйте `EnsureFrontendRequestsAreStateful`.
- Push не приходит: проверьте сервис-аккаунт, права FCM, корректность токена, включение уведомлений на устройстве.
