<?php

namespace App\Services;

use App\Enums\NotificationEventType;
use App\Models\AppNotification;
use App\Models\DeviceToken;
use App\Models\NotificationSetting;
use App\Models\User;
use Illuminate\Support\Facades\Log;
use Kreait\Firebase\Messaging\CloudMessage;
use Kreait\Firebase\Messaging\Notification;
use Kreait\Laravel\Firebase\Facades\Firebase;

/**
 * Push-диспетчер с проверкой согласий пользователя.
 * Отвечает за отправку push-уведомлений с учётом:
 * - системного разрешения ОС (наличие FCM токена)
 * - пользовательского согласия (главный toggle)
 * - настроек конкретного типа уведомления
 */
class PushDispatcher
{
    /**
     * Отправить push-уведомление пользователю.
     *
     * @param User $recipient Получатель
     * @param NotificationEventType $eventType Тип события
     * @param string $title Заголовок уведомления
     * @param string $body Текст уведомления
     * @param array $data Дополнительные данные (deeplink, entityId и т.д.)
     * @param User|null $actor Инициатор действия (для исключения самоуведомлений)
     * @return bool Успешность отправки
     */
    public function send(
        User $recipient,
        NotificationEventType $eventType,
        string $title,
        string $body,
        array $data = [],
        ?User $actor = null
    ): bool {
        // Правило: не уведомлять пользователя о собственных действиях
        if ($actor && $actor->id === $recipient->id) {
            return false;
        }

        // Проверяем, требуется ли push для данного типа события
        if (! $eventType->requiresPush()) {
            return false;
        }

        // Проверяем согласие пользователя
        if (! $this->checkUserConsent($recipient, $eventType)) {
            return false;
        }

        // Получаем FCM токены пользователя
        $tokens = $this->getActiveTokens($recipient);
        if ($tokens->isEmpty()) {
            return false;
        }

        // Формируем payload с deeplink
        $payload = $this->buildPayload($eventType, $data);

        // Отправляем push
        return $this->sendToTokens($tokens->toArray(), $title, $body, $payload);
    }

    /**
     * Отправить push нескольким пользователям.
     *
     * @param array<User> $recipients Получатели
     * @param NotificationEventType $eventType Тип события
     * @param string $title Заголовок
     * @param string $body Текст
     * @param array $data Данные
     * @param User|null $actor Инициатор
     * @return int Количество успешных отправок
     */
    public function sendToMany(
        array $recipients,
        NotificationEventType $eventType,
        string $title,
        string $body,
        array $data = [],
        ?User $actor = null
    ): int {
        $successCount = 0;

        foreach ($recipients as $recipient) {
            if ($this->send($recipient, $eventType, $title, $body, $data, $actor)) {
                $successCount++;
            }
        }

        return $successCount;
    }

    /**
     * Проверить согласие пользователя на получение уведомлений данного типа.
     */
    public function checkUserConsent(User $recipient, NotificationEventType $eventType): bool
    {
        $settings = $recipient->notificationSetting;

        // Если настроек нет — создаём с дефолтными значениями
        if (! $settings) {
            $settings = NotificationSetting::query()->create([
                'user_id' => $recipient->id,
            ]);
        }

        // Главный toggle — если выключен, никакие push не отправляются
        if (! $settings->push_enabled) {
            return false;
        }

        // Получаем ключ настройки для данного типа события
        $settingKey = $eventType->getSettingKey();

        // Если ключ не определён — событие не требует проверки настроек
        if ($settingKey === null) {
            return true;
        }

        // Проверяем конкретную настройку
        return (bool) ($settings->{$settingKey} ?? true);
    }

    /**
     * Получить активные FCM токены пользователя.
     */
    protected function getActiveTokens(User $user): \Illuminate\Support\Collection
    {
        return DeviceToken::query()
            ->where('user_id', $user->id)
            ->pluck('token');
    }

    /**
     * Сформировать payload для push-уведомления.
     */
    protected function buildPayload(NotificationEventType $eventType, array $data): array
    {
        $payload = [
            'eventType' => $eventType->value,
            'timestamp' => now()->toISOString(),
        ];

        // Добавляем entityId если есть
        if (isset($data['entity_id'])) {
            $payload['entityId'] = $data['entity_id'];
        }

        // Формируем deeplink
        $payload['deeplink'] = $this->buildDeeplink($eventType, $data);

        // Добавляем остальные данные
        foreach ($data as $key => $value) {
            if (! isset($payload[$key]) && is_scalar($value)) {
                $payload[$key] = (string) $value;
            }
        }

        return $payload;
    }

    /**
     * Сформировать deeplink для перехода в приложении.
     */
    protected function buildDeeplink(NotificationEventType $eventType, array $data): string
    {
        $baseUrl = 'chtohochu://';

        return match ($eventType) {
            // Списки желаний
            NotificationEventType::LIST_SHARED,
            NotificationEventType::LIST_DELETED,
            NotificationEventType::MEMBER_INVITED,
            NotificationEventType::MEMBER_JOINED,
            NotificationEventType::MEMBER_LEFT,
            NotificationEventType::MEMBER_REMOVED => $baseUrl . 'wishlist/' . ($data['list_id'] ?? ''),

            // Желания
            NotificationEventType::WISH_MARKED_DONE,
            NotificationEventType::WISH_COMMENTED => $baseUrl . 'wish/' . ($data['wish_id'] ?? ''),

            // Списки покупок
            NotificationEventType::SHOPPING_LIST_SHARED,
            NotificationEventType::SHOPPING_LIST_DELETED,
            NotificationEventType::SHOPPING_MEMBER_INVITED,
            NotificationEventType::SHOPPING_MEMBER_JOINED,
            NotificationEventType::SHOPPING_MEMBER_LEFT,
            NotificationEventType::SHOPPING_MEMBER_REMOVED,
            NotificationEventType::ITEM_CHECKED => $baseUrl . 'shopping-list/' . ($data['list_id'] ?? ''),

            // Социальные
            NotificationEventType::FRIEND_REQUEST,
            NotificationEventType::FRIEND_ACCEPTED => $baseUrl . 'friends',

            // Системные
            NotificationEventType::SYSTEM_ANNOUNCEMENT => $baseUrl . 'notifications',

            default => $baseUrl,
        };
    }

    /**
     * Отправить push на указанные токены через Firebase.
     */
    protected function sendToTokens(array $tokens, string $title, string $body, array $data): bool
    {
        if (empty($tokens)) {
            return false;
        }

        try {
            $messaging = Firebase::messaging();

            $notification = Notification::create($title, $body);

            foreach ($tokens as $token) {
                try {
                    $message = CloudMessage::withTarget('token', $token)
                        ->withNotification($notification)
                        ->withData($data);

                    $messaging->send($message);
                } catch (\Throwable $e) {
                    // Если токен невалидный — удаляем его
                    if ($this->isInvalidTokenError($e)) {
                        DeviceToken::query()->where('token', $token)->delete();
                    }

                    Log::warning('Push send failed', [
                        'token' => substr($token, 0, 20) . '...',
                        'error' => $e->getMessage(),
                    ]);
                }
            }

            return true;
        } catch (\Throwable $e) {
            Log::error('Push dispatcher error', [
                'error' => $e->getMessage(),
            ]);

            return false;
        }
    }

    /**
     * Проверить, является ли ошибка ошибкой невалидного токена.
     */
    protected function isInvalidTokenError(\Throwable $e): bool
    {
        $message = strtolower($e->getMessage());

        return str_contains($message, 'not a valid fcm')
            || str_contains($message, 'unregistered')
            || str_contains($message, 'invalid registration');
    }

    /**
     * Сохранить уведомление в БД и отправить push.
     */
    public function notify(
        User $recipient,
        NotificationEventType $eventType,
        string $title,
        string $body,
        array $data = [],
        ?User $actor = null
    ): ?AppNotification {
        // Правило: не уведомлять пользователя о собственных действиях
        if ($actor && $actor->id === $recipient->id) {
            return null;
        }

        // Сохраняем уведомление в БД
        $notification = AppNotification::create([
            'user_id' => $recipient->id,
            'type' => $eventType->value,
            'title' => $title,
            'body' => $body,
            'data' => $data,
        ]);

        // Отправляем push
        $this->send($recipient, $eventType, $title, $body, $data, $actor);

        return $notification;
    }
}
