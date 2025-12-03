<?php

use Illuminate\Support\Facades\Route;

// Доменные сегменты загружаются первыми для корректной работы мультидоменной маршрутизации
require __DIR__ . '/landing.php';
require __DIR__ . '/user.php';
require __DIR__ . '/admin.php';

require __DIR__ . '/auth.php';
