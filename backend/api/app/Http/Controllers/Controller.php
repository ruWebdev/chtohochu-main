<?php

namespace App\Http\Controllers;

use Illuminate\Database\QueryException;
use Illuminate\Foundation\Auth\Access\AuthorizesRequests;
use Illuminate\Foundation\Validation\ValidatesRequests;
use Illuminate\Routing\Controller as BaseController;

abstract class Controller extends BaseController
{
    use AuthorizesRequests, ValidatesRequests;

    /**
     * PostgreSQL unique-violation (SQLSTATE 23505) на PK —
     * повторный POST с уже существующим client-generated UUID.
     * Только duplicate key: остальные QueryException пробрасываем
     * дальше как server errors.
     */
    protected function isDuplicateKeyViolation(QueryException $e): bool
    {
        return ($e->errorInfo[0] ?? null) === '23505';
    }
}
