<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\SharedWishListResource;
use App\Http\Resources\SharedWishResource;
use App\Http\Resources\ShareResource;
use App\Models\Share;
use App\Models\User;
use App\Models\Wish;
use App\Models\WishList;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\QueryException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ShareController extends Controller
{
    /**
     * Максимум желаний в публичном списке — защита от тяжёлых
     * ответов. Pagination для MVP не реализуется.
     */
    private const SHARED_WISHES_LIMIT = 200;

    /**
     * Создать share для желания. Только владелец (WishPolicy::update
     * — owner-only ability); чужое желание → 404, существование
     * не раскрывается. Идемпотентно: активный share уже есть —
     * возвращается он, новый не создаётся.
     */
    public function storeForWish(Request $request, Wish $wish): JsonResponse
    {
        abort_unless($request->user()->can('update', $wish), 404);

        return $this->shareFor($request->user(), $wish);
    }

    /**
     * Создать share для списка желаний. Только владелец;
     * soft-deleted список не биндится в маршрут → 404.
     * Идемпотентно, как и для желания.
     */
    public function storeForWishList(Request $request, WishList $wishList): JsonResponse
    {
        abort_unless($request->user()->can('update', $wishList), 404);

        return $this->shareFor($request->user(), $wishList);
    }

    /**
     * Отозвать share. Только владелец; чужой → 404. Повторный
     * revoke безопасен: запись не удаляется, revoked_at просто
     * проставляется.
     */
    public function destroy(Request $request, Share $share): JsonResponse
    {
        abort_unless($request->user()->id === $share->owner_id, 404);

        if ($share->revoked_at === null) {
            $share->forceFill(['revoked_at' => now()])->save();
        }

        return response()->json(null, 204);
    }

    /**
     * Публичный resolver по capability-токену — единственная
     * точка анонимного доступа к чужому контенту. Единый 404
     * для всех «недействительных» состояний: нет токена,
     * revoked, expired, удалённая/soft-deleted сущность —
     * причина не раскрывается.
     *
     * Токен генерируется сервером и не связан с UUID сущности —
     * через этот endpoint enumeration объектов невозможен.
     */
    public function show(Request $request, string $token): JsonResponse
    {
        $share = Share::active()
            ->where('token', $token)
            ->where(
                fn ($q) => $q
                    ->whereNull('expires_at')
                    ->orWhere('expires_at', '>', now())
            )
            ->with('shareable')
            ->first();

        $shareable = $share?->shareable;
        // null: нет share, revoked/expired, entity удалена
        // (soft-deleted WishList глобальным scope не подгружается).
        abort_if($shareable === null, 404);

        $data = match (true) {
            $shareable instanceof Wish => [
                'type' => 'wish',
                'data' => (new SharedWishResource(
                    $shareable->loadMissing('owner')
                ))->toArray($request),
            ],
            $shareable instanceof WishList => [
                'type' => 'wish_list',
                'data' => (new SharedWishListResource(
                    $shareable->loadMissing([
                        'owner',
                        'wishes' => fn ($q) => $q
                            ->latest('created_at')
                            ->limit(self::SHARED_WISHES_LIMIT),
                    ])
                ))->toArray($request),
            ],
            default => abort(404),
        };

        // Capability-ответ не кэшируем публичными кэшами.
        return response()->json($data)
            ->header('Cache-Control', 'private, no-store');
    }

    /**
     * Идемпотентное создание share: активный уже есть — вернуть
     * его («один активный share на сущность» для MVP без
     * partial unique index).
     *
     * @param  Wish|WishList  $entity
     */
    private function shareFor(User $owner, Model $entity): JsonResponse
    {
        $share = Share::where('owner_id', $owner->id)
            ->where('shareable_type', $entity->getMorphClass())
            ->where('shareable_id', $entity->getKey())
            ->active()
            ->first();

        $share ??= $this->createShare($owner, $entity);

        return (new ShareResource($share))
            ->toResponse(request())
            ->setStatusCode(201);
    }

    /**
     * Новый share с серверным token. Token — 32 случайных байта
     * в base64url (43 символа, ~256 бит энтропии). Коллизия по
     * unique-индексу практически невозможна, но retry на
     * duplicate key — дешёвая страховка.
     */
    private function createShare(User $owner, Model $entity): Share
    {
        for ($attempt = 0; $attempt < 3; $attempt++) {
            try {
                return Share::create([
                    'owner_id' => $owner->id,
                    'shareable_type' => $entity->getMorphClass(),
                    'shareable_id' => $entity->getKey(),
                    'token' => $this->generateToken(),
                ]);
            } catch (QueryException $e) {
                abort_unless($this->isDuplicateKeyViolation($e), 500);
            }
        }

        abort(500);
    }

    /**
     * URL-safe token: 32 байта → base64url без padding (43 симв.).
     * Не UUID сущности, не хэш — независимый capability.
     */
    private function generateToken(): string
    {
        return rtrim(strtr(base64_encode(random_bytes(32)), '+/', '-_'), '=');
    }
}
