<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\SearchUsersRequest;
use App\Http\Resources\PublicUserResource;
use App\Models\User;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class UserController extends Controller
{
    /**
     * Поиск пользователей по name/username, case-insensitive.
     * Ведущий '@' снимается в SearchUsersRequest.
     * Лимит 20, без пагинации. Email не отдаём.
     */
    public function search(SearchUsersRequest $request): AnonymousResourceCollection
    {
        // Экранируем LIKE-метасимволы.
        $escaped = str_replace(['\\', '%', '_'], ['\\\\', '\%', '\_'], $request->validated('q'));

        $users = User::query()
            ->where('users.id', '!=', $request->user()->id)
            ->where(function ($w) use ($escaped) {
                $w->where('username', 'ilike', "{$escaped}%")
                    ->orWhere('name', 'ilike', "%{$escaped}%");
            })
            ->orderBy('username')
            ->limit(20)
            ->get();

        return PublicUserResource::collection($users);
    }
}
