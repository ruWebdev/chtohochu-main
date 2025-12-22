<template>
    <LandingLayout :title="pageTitle">
        <section class="landing-hero space-y-6">
            <!-- Ошибочное состояние -->
            <div v-if="status !== 'ok'" class="space-y-3">
                <h1 class="landing-hero__title">{{ errorTitle }}</h1>
                <p class="landing-hero__subtitle">{{ errorText }}</p>
            </div>

            <!-- Основное содержимое списка -->
            <div v-else class="space-y-4">
                <!-- Заголовок списка -->
                <header class="space-y-2">
                    <h1 class="text-2xl font-semibold text-gray-900 break-words">{{ headerTitle }}</h1>
                    <p class="text-sm text-gray-500">
                        {{ listTypeLabel }} · {{ ownerNameLabel }}
                    </p>
                </header>

                <!-- Элементы списка желаний -->
                <ul v-if="isWishlist" class="space-y-2 max-h-[60vh] overflow-y-auto">
                    <li v-for="wish in wishlist.wishes_preview" :key="wish.id"
                        class="bg-white rounded-lg shadow-sm px-4 py-3 text-left">
                        <span class="text-gray-900 font-medium">{{ wish.name }}</span>
                    </li>
                </ul>

                <!-- Элементы списка покупок -->
                <ul v-else-if="isShoppingList" class="space-y-2 max-h-[60vh] overflow-y-auto">
                    <li v-for="item in shoppingList.items_preview" :key="item.id"
                        class="bg-white rounded-lg shadow-sm px-4 py-3 flex items-center justify-between">
                        <span class="font-medium"
                            :class="item.is_purchased ? 'text-gray-400 line-through' : 'text-gray-900'">
                            {{ item.name }}
                        </span>
                    </li>
                </ul>

                <!-- Разовые желания (если шарится одно желание) -->
                <div v-else-if="isWish" class="bg-white rounded-lg shadow-sm px-4 py-4 text-left space-y-2">
                    <h2 class="text-lg font-semibold text-gray-900">{{ wish.name }}</h2>
                    <p v-if="wish.description" class="text-gray-600 text-sm">{{ wish.description }}</p>
                </div>
            </div>

            <!-- CTA-блок внизу -->
            <div class="mt-4 pt-4 border-t border-gray-200 space-y-3">
                <p class="text-sm text-gray-600">
                    Установите приложение «Что Хочу», чтобы редактировать списки, отмечать покупки и
                    приглашать друзей.
                </p>
                <div class="flex flex-col items-stretch gap-2">
                    <a :href="deeplink" class="btn btn-primary w-full text-center">Открыть в приложении</a>
                    <a :href="storeUrl" class="btn btn-secondary w-full text-center">Установить приложение</a>
                </div>
            </div>
        </section>
    </LandingLayout>
</template>

<script setup>
import { computed } from 'vue';
import { usePage } from '@inertiajs/vue3';
import LandingLayout from '@/Layouts/LandingLayout.vue';

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
