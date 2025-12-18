<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ShoppingList;
use App\Models\Wishlist;
use App\Models\Wish;
use App\Models\ShareToken;
use App\Models\User;
use App\Events\Share\ShareLinkCreated;
use App\Events\Share\ShareLinkOpened;
use App\Events\Share\UserJoinedViaShare;
use App\Events\Share\WishAddedViaShare;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

/**
 * Контроллер для управления share-ссылками.
 * Поддерживает генерацию, resolve и присоединение по ссылке.
 */
class ShareController extends Controller
{
    /**
     * POST /share/link
     * Универсальный эндпоинт для генерации share-ссылки.
     */
    public function createLink(Request $request)
    {
        $data = $request->validate([
            'entity_type' => ['required', 'string', 'in:wish,wishlist,shopping_list'],
            'entity_id' => ['required', 'uuid'],
            'access_type' => ['sometimes', 'string', 'in:public,by_link,friends'],
            'role' => ['sometimes', 'string', 'in:viewer,editor'],
        ]);

        $entityType = $data['entity_type'];
        $entityId = $data['entity_id'];
        $accessType = $data['access_type'] ?? ShareToken::ACCESS_BY_LINK;
        $role = $data['role'] ?? 'viewer';

        // Получаем сущность и проверяем права
        $entity = $this->getEntityOrFail($entityType, $entityId);
        $this->authorizeShare($entity, $entityType);

        // Формируем метаданные
        $metadata = $this->buildMetadata($entity, $entityType);

        // Создаём или получаем существующий активный токен
        $shareToken = ShareToken::forEntity($entityType, $entityId)
            ->active()
            ->where('access_type', $accessType)
            ->where('created_by', $request->user()->id)
            ->first();

        if (!$shareToken) {
            $shareToken = ShareToken::create([
                'entity_type' => $entityType,
                'entity_id' => $entityId,
                'access_type' => $accessType,
                'role' => $role,
                'title' => $metadata['title'],
                'description' => $metadata['description'],
                'preview_image_url' => $metadata['preview_image_url'],
                'created_by' => $request->user()->id,
            ]);

            event(new ShareLinkCreated($shareToken, $request->user()));
        }

        return response()->json([
            'data' => [
                'share_url' => $shareToken->getShareUrl(),
                'deeplink' => $shareToken->getDeeplink(),
                'title' => $shareToken->title,
                'description' => $shareToken->description,
                'preview_image_url' => $shareToken->preview_image_url,
                'qr_code_url' => route('api.qr.generate', [
                    'type' => $entityType,
                    'id' => $entityId,
                ]),
                'expires_at' => $shareToken->expires_at?->toIso8601String(),
            ],
        ]);
    }

    /**
     * GET /share/resolve/{token}
     * Разрешает share-токен и возвращает информацию о сущности.
     */
    public function resolve(Request $request, string $token)
    {
        $shareToken = ShareToken::byToken($token)->first();

        if (!$shareToken) {
            return response()->json([
                'error' => 'not_found',
                'message' => 'Ссылка не найдена',
            ], 404);
        }

        if ($shareToken->isRevoked()) {
            return response()->json([
                'error' => 'revoked',
                'message' => 'Ссылка была отозвана',
            ], 410);
        }

        if (!$shareToken->isActive()) {
            return response()->json([
                'error' => 'expired',
                'message' => 'Срок действия ссылки истёк',
            ], 410);
        }

        $entity = $shareToken->getEntity();

        if (!$entity) {
            return response()->json([
                'error' => 'entity_deleted',
                'message' => 'Объект больше недоступен',
            ], 410);
        }

        // Отправляем событие открытия ссылки
        event(new ShareLinkOpened($shareToken, $request->user()));

        $user = $request->user();
        $responseData = $this->buildResolveResponse($shareToken, $entity, $user);

        return response()->json(['data' => $responseData]);
    }

    /**
     * POST /share/join/{token}
     * Присоединение к списку по share-ссылке.
     */
    public function join(Request $request, string $token)
    {
        $shareToken = ShareToken::byToken($token)->first();

        if (!$shareToken || !$shareToken->isActive()) {
            return response()->json([
                'error' => 'invalid_link',
                'message' => 'Ссылка недействительна',
            ], 400);
        }

        $entity = $shareToken->getEntity();

        if (!$entity) {
            return response()->json([
                'error' => 'entity_deleted',
                'message' => 'Объект больше недоступен',
            ], 410);
        }

        $user = $request->user();

        // Проверяем, что это список (wishlist или shopping_list)
        if (!in_array($shareToken->entity_type, [ShareToken::ENTITY_WISHLIST, ShareToken::ENTITY_SHOPPING_LIST])) {
            return response()->json([
                'error' => 'not_joinable',
                'message' => 'К этому объекту нельзя присоединиться',
            ], 400);
        }

        // Проверяем, не является ли пользователь владельцем
        if ($entity->owner_id === $user->id) {
            return response()->json([
                'error' => 'already_owner',
                'message' => 'Вы являетесь владельцем этого списка',
            ], 400);
        }

        // Проверяем, не является ли пользователь уже участником
        if ($entity->participants()->where('user_id', $user->id)->exists()) {
            return response()->json([
                'data' => [
                    'status' => 'already_member',
                    'message' => 'Вы уже являетесь участником этого списка',
                    'entity_type' => $shareToken->entity_type,
                    'entity_id' => $shareToken->entity_id,
                ],
            ]);
        }

        // Добавляем пользователя как участника
        $role = $shareToken->role ?? 'viewer';
        $entity->participants()->attach($user->id, ['role' => $role]);

        // Отправляем событие
        event(new UserJoinedViaShare($shareToken, $user, $entity));

        return response()->json([
            'data' => [
                'status' => 'joined',
                'message' => 'Вы успешно присоединились к списку',
                'entity_type' => $shareToken->entity_type,
                'entity_id' => $shareToken->entity_id,
                'role' => $role,
            ],
        ]);
    }

    /**
     * POST /share/copy-wish/{token}
     * Копирование желания себе по share-ссылке.
     */
    public function copyWish(Request $request, string $token)
    {
        $data = $request->validate([
            'wishlist_id' => ['required', 'uuid'],
        ]);

        $shareToken = ShareToken::byToken($token)->first();

        if (!$shareToken || !$shareToken->isActive()) {
            return response()->json([
                'error' => 'invalid_link',
                'message' => 'Ссылка недействительна',
            ], 400);
        }

        if ($shareToken->entity_type !== ShareToken::ENTITY_WISH) {
            return response()->json([
                'error' => 'not_a_wish',
                'message' => 'Эта ссылка не ведёт на желание',
            ], 400);
        }

        $originalWish = $shareToken->getEntity();

        if (!$originalWish) {
            return response()->json([
                'error' => 'wish_deleted',
                'message' => 'Желание больше недоступно',
            ], 410);
        }

        $user = $request->user();
        $targetWishlist = Wishlist::where('id', $data['wishlist_id'])
            ->where('owner_id', $user->id)
            ->first();

        if (!$targetWishlist) {
            return response()->json([
                'error' => 'wishlist_not_found',
                'message' => 'Список желаний не найден',
            ], 404);
        }

        // Создаём копию желания
        $newWish = $originalWish->replicate([
            'id',
            'created_at',
            'updated_at',
            'executor_user_id',
            'purchase_receipt',
            'purchase_date',
        ]);
        $newWish->wishlist_id = $targetWishlist->id;
        $newWish->owner_id = $user->id;
        $newWish->status = Wish::STATUS_NOT_FULFILLED;
        $newWish->save();

        // Отправляем событие
        event(new WishAddedViaShare($shareToken, $user, $originalWish, $newWish));

        return response()->json([
            'data' => [
                'status' => 'copied',
                'message' => 'Желание добавлено в ваш список',
                'wish_id' => $newWish->id,
                'wishlist_id' => $targetWishlist->id,
            ],
        ]);
    }

    /**
     * DELETE /share/links/{token}
     * Отзыв share-ссылки.
     */
    public function revokeLink(Request $request, string $token)
    {
        $shareToken = ShareToken::byToken($token)
            ->where('created_by', $request->user()->id)
            ->first();

        if (!$shareToken) {
            return response()->json([
                'error' => 'not_found',
                'message' => 'Ссылка не найдена',
            ], 404);
        }

        $shareToken->revoke();

        return response()->json([
            'data' => [
                'status' => 'revoked',
                'message' => 'Ссылка отозвана',
            ],
        ]);
    }

    // =========================================================================
    // Устаревшие методы для обратной совместимости
    // =========================================================================

    public function wishlist(Request $request, Wishlist $wishlist)
    {
        $this->authorize('view', $wishlist);

        $data = $request->validate([
            'access_type' => ['sometimes', 'string', 'in:public,by_link,friends'],
        ]);

        $accessType = $data['access_type'] ?? 'by_link';

        return $this->createLinkForEntity(
            $request,
            ShareToken::ENTITY_WISHLIST,
            $wishlist->id,
            $accessType,
            $wishlist
        );
    }

    public function wish(Request $request, Wishlist $wishlist, Wish $wish)
    {
        $this->authorize('view', $wishlist);

        if ($wish->wishlist_id !== $wishlist->id) {
            abort(404);
        }

        return $this->createLinkForEntity(
            $request,
            ShareToken::ENTITY_WISH,
            $wish->id,
            'by_link',
            $wish
        );
    }

    public function shoppingList(Request $request, ShoppingList $shoppingList)
    {
        $this->authorize('view', $shoppingList);

        $data = $request->validate([
            'access_type' => ['sometimes', 'string', 'in:public,by_link,friends'],
            'role' => ['sometimes', 'string', 'in:viewer,editor'],
        ]);

        $accessType = $data['access_type'] ?? 'by_link';
        $role = $data['role'] ?? 'editor';

        return $this->createLinkForEntity(
            $request,
            ShareToken::ENTITY_SHOPPING_LIST,
            $shoppingList->id,
            $accessType,
            $shoppingList,
            $role
        );
    }

    public function me(Request $request)
    {
        $user = $request->user();
        $path = 'user/' . $user->username;

        return response()->json([
            'data' => $this->buildLegacySharePayload($path, 'user', 'public'),
        ]);
    }

    public function app(Request $request)
    {
        $path = 'app';
        $base = $this->buildLegacySharePayload($path, 'app', 'public');

        return response()->json([
            'data' => array_merge($base, [
                'app_store_url' => config('sharing.app_store_url'),
                'play_store_url' => config('sharing.play_store_url'),
            ]),
        ]);
    }

    // =========================================================================
    // Приватные методы
    // =========================================================================

    private function getEntityOrFail(string $entityType, string $entityId)
    {
        $entity = match ($entityType) {
            ShareToken::ENTITY_WISH => Wish::find($entityId),
            ShareToken::ENTITY_WISHLIST => Wishlist::find($entityId),
            ShareToken::ENTITY_SHOPPING_LIST => ShoppingList::find($entityId),
            default => null,
        };

        if (!$entity) {
            abort(404, 'Объект не найден');
        }

        return $entity;
    }

    private function authorizeShare($entity, string $entityType): void
    {
        $policyMethod = 'view';

        if ($entityType === ShareToken::ENTITY_WISH) {
            $this->authorize($policyMethod, $entity->wishlist);
        } else {
            $this->authorize($policyMethod, $entity);
        }
    }

    private function buildMetadata($entity, string $entityType): array
    {
        $title = '';
        $description = '';
        $previewImageUrl = null;

        switch ($entityType) {
            case ShareToken::ENTITY_WISH:
                $title = $entity->name;
                $description = $entity->description ?? '';
                $images = $entity->getFullImageUrls();
                $previewImageUrl = $images[0] ?? null;
                break;

            case ShareToken::ENTITY_WISHLIST:
                $title = $entity->name;
                $description = $entity->description ?? 'Список желаний';
                if ($entity->avatar) {
                    $previewImageUrl = Storage::url($entity->avatar);
                }
                break;

            case ShareToken::ENTITY_SHOPPING_LIST:
                $title = $entity->name;
                $description = $entity->description ?? 'Список покупок';
                if ($entity->avatar) {
                    $previewImageUrl = Storage::url($entity->avatar);
                }
                break;
        }

        return [
            'title' => $title,
            'description' => $description,
            'preview_image_url' => $previewImageUrl,
        ];
    }

    private function buildResolveResponse(ShareToken $shareToken, $entity, ?User $user): array
    {
        $entityType = $shareToken->entity_type;
        $isAuthenticated = $user !== null;
        $isOwner = $isAuthenticated && $entity->owner_id === $user->id;
        $isMember = false;

        if ($isAuthenticated && in_array($entityType, [ShareToken::ENTITY_WISHLIST, ShareToken::ENTITY_SHOPPING_LIST])) {
            $isMember = $entity->participants()->where('user_id', $user->id)->exists();
        }

        $response = [
            'entity_type' => $entityType,
            'entity_id' => $shareToken->entity_id,
            'title' => $shareToken->title,
            'description' => $shareToken->description,
            'preview_image_url' => $shareToken->preview_image_url,
            'is_authenticated' => $isAuthenticated,
            'is_owner' => $isOwner,
            'is_member' => $isMember || $isOwner,
            'can_join' => $isAuthenticated && !$isOwner && !$isMember && $entityType !== ShareToken::ENTITY_WISH,
            'can_copy' => $isAuthenticated && !$isOwner && $entityType === ShareToken::ENTITY_WISH,
        ];

        // Добавляем данные владельца
        $response['owner'] = [
            'id' => $entity->owner->id,
            'name' => $entity->owner->name,
            'avatar' => $entity->owner->avatar_url,
        ];

        // Для желаний добавляем дополнительные данные
        if ($entityType === ShareToken::ENTITY_WISH) {
            $response['wish'] = [
                'id' => $entity->id,
                'name' => $entity->name,
                'description' => $entity->description,
                'images' => $entity->getFullImageUrls(),
                'desired_price' => $entity->desired_price,
                'url' => $entity->url,
                'status' => $entity->status,
            ];
        }

        return $response;
    }

    private function createLinkForEntity(
        Request $request,
        string $entityType,
        string $entityId,
        string $accessType,
        $entity,
        string $role = 'viewer'
    ) {
        $metadata = $this->buildMetadata($entity, $entityType);

        $shareToken = ShareToken::forEntity($entityType, $entityId)
            ->active()
            ->where('access_type', $accessType)
            ->where('created_by', $request->user()->id)
            ->first();

        if (!$shareToken) {
            $shareToken = ShareToken::create([
                'entity_type' => $entityType,
                'entity_id' => $entityId,
                'access_type' => $accessType,
                'role' => $role,
                'title' => $metadata['title'],
                'description' => $metadata['description'],
                'preview_image_url' => $metadata['preview_image_url'],
                'created_by' => $request->user()->id,
            ]);

            event(new ShareLinkCreated($shareToken, $request->user()));
        }

        return response()->json([
            'data' => [
                'url' => $shareToken->getShareUrl(),
                'deeplink' => $shareToken->getDeeplink(),
                'qr_code_url' => route('api.qr.generate', [
                    'type' => $entityType,
                    'id' => $entityId,
                ]),
                'expires_at' => $shareToken->expires_at?->toIso8601String(),
            ],
        ]);
    }

    private function buildLegacySharePayload(string $path, string $type, string $accessType): array
    {
        $baseUrl = rtrim((string) config('sharing.share_base_url'), '/');
        $scheme = (string) config('sharing.deep_link_scheme', 'chtohochu');

        $normalizedPath = ltrim($path, '/');

        $url = $baseUrl . '/' . $normalizedPath;
        $deeplink = $scheme . '://' . $normalizedPath;

        $qrUrl = route('api.qr.generate', [
            'type' => $type,
            'id' => $type === 'app' ? null : basename($normalizedPath),
        ]);

        return [
            'url' => $url,
            'deeplink' => $deeplink,
            'qr_code_url' => $qrUrl,
            'expires_at' => null,
        ];
    }
}
