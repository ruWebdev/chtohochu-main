<script setup>
import { Head, Link } from '@inertiajs/vue3';

defineProps({
    canLogin: {
        type: Boolean,
    },
    canRegister: {
        type: Boolean,
    },
});
</script>

<template>
    <Head title="ЧтоХочу" />
    <div class="min-h-screen bg-gradient-to-br from-white via-slate-50 to-slate-100 text-slate-900">
        <div class="relative flex min-h-screen flex-col items-center justify-center px-6 py-10">
            <div class="w-full max-w-4xl rounded-2xl bg-white/80 p-8 shadow-xl ring-1 ring-slate-200 backdrop-blur">
                <header class="flex flex-col gap-4 pb-6 md:flex-row md:items-center md:justify-between">
                    <div>
                        <p class="text-sm uppercase tracking-[0.18em] text-slate-500">Добро пожаловать</p>
                        <h1 class="text-3xl font-semibold text-slate-900">ЧтоХочу</h1>
                        <p class="mt-2 text-slate-600">
                            Управляйте желаниями и списками покупок, делитесь с друзьями и следите за выполнением.
                        </p>
                    </div>
                    <nav v-if="canLogin" class="flex items-center gap-3">
                        <Link
                            v-if="$page.props.auth.user"
                            :href="route('dashboard')"
                            class="rounded-lg border border-slate-200 px-4 py-2 text-slate-800 transition hover:border-slate-300 hover:bg-slate-50"
                        >
                            Перейти в приложение
                        </Link>
                        <template v-else>
                            <Link
                                :href="route('login')"
                                class="rounded-lg border border-slate-200 px-4 py-2 text-slate-800 transition hover:border-slate-300 hover:bg-slate-50"
                            >
                                Войти
                            </Link>
                            <Link
                                v-if="canRegister"
                                :href="route('register')"
                                class="rounded-lg bg-slate-900 px-4 py-2 text-white transition hover:bg-slate-800"
                            >
                                Зарегистрироваться
                            </Link>
                        </template>
                    </nav>
                </header>

                <main class="grid gap-6 md:grid-cols-2">
                    <section class="rounded-xl border border-slate-100 bg-slate-50/60 p-5">
                        <h2 class="text-lg font-semibold text-slate-900">Списки покупок</h2>
                        <p class="mt-2 text-sm text-slate-600">
                            Создавайте списки, добавляйте товары, отмечайте покупки и делитесь с близкими.
                        </p>
                    </section>
                    <section class="rounded-xl border border-slate-100 bg-slate-50/60 p-5">
                        <h2 class="text-lg font-semibold text-slate-900">Желания</h2>
                        <p class="mt-2 text-sm text-slate-600">
                            Храните идеи подарков и желаний, прикрепляйте фото и ссылки, отслеживайте статус.
                        </p>
                    </section>
                </main>
            </div>
        </div>
    </div>
</template>
