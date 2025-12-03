<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;

class UserController extends Controller
{
    /**
     * Поиск пользователей по email.
     */
    public function search(Request $request)
    {
        $currentUser = $request->user();

        $data = $request->validate([
            'email' => ['required', 'string', 'max:255'],
        ]);

        $query = User::query()
            ->where('id', '!=', $currentUser->id)
            ->where('email', 'like', $data['email'] . '%')
            ->orderBy('email')
            ->limit(20);

        return response()->json([
            'data' => $query->get(['id', 'name', 'email']),
        ]);
    }
}
