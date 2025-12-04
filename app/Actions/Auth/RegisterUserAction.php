<?php

namespace App\Actions\Auth;

use App\Models\User;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\DB;

class RegisterUserAction
{
    /**
     * Регистрация нового пользователя.
     */
    public function execute(array $data): User
    {
        return DB::transaction(function () use ($data) {
            $username = strtolower($data['username']);

            $user = new User();
            $user->name = $data['username'];
            $user->username = $username;
            $user->email = $data['email'];
            $user->password = Hash::make($data['password']);
            $user->save();

            return $user;
        });
    }
}
