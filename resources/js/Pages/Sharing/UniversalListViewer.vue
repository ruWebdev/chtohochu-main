<template>

    <Head :title="pageTitle" />
    <SharingLayout>
        <section class="space-y-6">
            <!-- Ошибочное состояние -->
            <div v-if="status !== 'ok'" class="space-y-3 text-center">
                <h1 class="text-2xl font-semibold text-gray-900">{{ errorTitle }}</h1>
                <p class="text-sm text-gray-600">{{ errorText }}</p>
            </div>

            <!-- Основное содержимое списка -->
            <div v-else class="space-y-5">
                <!-- Заголовок списка -->
                <header class="bg-white rounded-2xl shadow-sm px-4 py-4 space-y-1">
                    <p class="text-xs font-semibold text-[#f97316] uppercase tracking-wide">{{ listTypeLabel }}</p>
                    <h1 class="text-2xl font-semibold text-gray-900 break-words">{{ headerTitle }}</h1>
                    <p class="text-sm text-gray-500">{{ ownerNameLabel }}</p>
                </header>

                <!-- Элементы списка желаний -->
                <ul v-if="isWishlist" class="space-y-3">
                    <li v-for="wish in wishlist.wishes_preview" :key="wish.id"
                        class="bg-white rounded-2xl shadow-sm px-4 py-3 flex items-center gap-3">
                        <div
                            class="w-12 h-12 rounded-xl bg-orange-50 flex items-center justify-center text-[#f97316] font-semibold">
                            {{ wish.name?.charAt(0) || '•' }}
                        </div>
                        <div class="flex-1">
                            <p class="text-base font-semibold text-gray-900">{{ wish.name }}</p>
                        </div>
                    </li>
                </ul>

                <!-- Элементы списка покупок -->
                <ul v-else-if="isShoppingList" class="space-y-3">
                    <li v-for="item in shoppingList.items_preview" :key="item.id"
                        class="bg-white rounded-2xl shadow-sm px-4 py-3 flex items-center justify-between">
                        <div class="flex items-center gap-3">
                            <div class="w-12 h-12 rounded-xl bg-orange-50 flex items-center justify-center">
                                <span class="text-sm font-semibold"
                                    :class="item.is_purchased ? 'text-gray-400' : 'text-[#f97316]'">
                                    ✓
                                </span>
                            </div>
                            <p class="text-base font-semibold"
                                :class="item.is_purchased ? 'text-gray-400 line-through' : 'text-gray-900'">
                                {{ item.name }}
                            </p>
                        </div>
                    </li>
                </ul>

                <!-- Разовые желания (если шарится одно желание) -->
                <div v-else-if="isWish" class="bg-white rounded-2xl shadow-sm px-4 py-4 space-y-2">
                    <h2 class="text-lg font-semibold text-gray-900">{{ wish.name }}</h2>
                    <p v-if="wish.description" class="text-gray-600 text-sm">{{ wish.description }}</p>
                </div>
            </div>

            <!-- CTA-блок внизу -->
            <div class="mt-4 space-y-3 bg-white rounded-2xl shadow-sm px-4 py-4">
                <p class="text-sm text-gray-700">
                    Установите приложение «Что Хочу», чтобы редактировать списки, отмечать покупки и приглашать друзей.
                </p>
                <div class="flex flex-col items-stretch gap-2">
                    <a :href="deeplink"
                        class="w-full h-12 rounded-full bg-[#f97316] text-white font-semibold flex items-center justify-center">
                        Открыть в приложении
                    </a>
                    <a :href="storeUrl"
                        class="w-full h-12 rounded-full border border-[#f97316] text-[#f97316] font-semibold flex items-center justify-center bg-white">
                        Установить приложение
                    </a>
                </div>
            </div>
        </section>
    </SharingLayout>
</template>

<script setup>
import { computed } from 'vue';
import { usePage } from '@inertiajs/vue3';
import { Head } from '@inertiajs/vue3';
import SharingLayout from '@/Layouts/SharingLayout.vue';

const page = usePage();
const props = page.props;

const status = computed(() => props.status || 'ok');
const entityType = computed(() => props.entity_type || null);

const ownerName = computed(() => props.owner?.name || 'пользователя');
const ownerNameLabel = computed(() => `от ${ownerName.value}`);

const wishlist = computed(() => props.wishlist || null);
const shoppingList = computed(() => props.shopping_list || null);
const wish = computed(() => props.wish || null);

const appStoreUrl = computed(() => props.app_store_url || '');
const playStoreUrl = computed(() => props.play_store_url || '');

const deeplink = computed(() => props.deeplink || '#');
const storeUrl = computed(() => props.play_store_url || props.app_store_url || '#');

const isWishlist = computed(() => entityType.value === 'wishlist');
const isShoppingList = computed(() => entityType.value === 'shopping_list');
const isWish = computed(() => entityType.value === 'wish');

const listTypeLabel = computed(() => {
    if (isWishlist.value) return 'Список желаний';
    if (isShoppingList.value) return 'Список покупок';
    if (isWish.value) return 'Желание';
    return '';
});

const pageTitle = computed(() => {
    if (status.value !== 'ok') {
        return 'Список недоступен';
    }
    if (isWishlist.value && wishlist.value) return wishlist.value.name;
    if (isShoppingList.value && shoppingList.value) return shoppingList.value.name;
    if (isWish.value && wish.value) return wish.value.name;
    return 'Список';
});

const headerTitle = computed(() => pageTitle.value);

const errorTitle = computed(() => {
    switch (status.value) {
        case 'not_found':
            return 'Список не найден';
        case 'revoked':
            return 'Доступ к списку был отозван';
        case 'expired':
            return 'Срок действия ссылки истёк';
        case 'entity_deleted':
            return 'Список больше недоступен';
        default:
            return 'Список недоступен';
    }
});

const errorText = computed(() => {
    switch (status.value) {
        case 'not_found':
            return 'Проверьте корректность ссылки или создайте свой список в приложении «Что Хочу».';
        case 'revoked':
            return 'Владелец закрыл доступ к этому списку. Вы можете создать свой список в приложении.';
        case 'expired':
            return 'Срок действия этой ссылки истёк. Создайте свой список и поделитесь им с друзьями.';
        case 'entity_deleted':
            return 'Этот список был удалён. Попробуйте создать свой собственный список.';
        default:
            return 'Список недоступен. Попробуйте открыть ссылку позже или создайте свой список.';
    }
});
</script>
