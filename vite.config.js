import { defineConfig } from 'vite';
import laravel from 'laravel-vite-plugin';
import vue from '@vitejs/plugin-vue';

export default defineConfig({
    server: {
        host: '0.0.0.0',         // слушает все сетевые интерфейсы
        port: 5182,              // можно изменить
        strictPort: true,
        hmr: {
            host: 'localhost',   // браузер будет подключаться к dev-server по HMR
            protocol: 'ws',
        },
        cors: true,              // включаем CORS, чтобы оба домена могли обращаться
    },
    plugins: [
        laravel({
            input: [
                'resources/js/app.js',
            ],
            refresh: true,
        }),
        vue({
            template: {
                transformAssetUrls: {
                    base: null,
                    includeAbsolute: false,
                },
            },
        }),
    ],
});
