<template>
    <LandingLayout :title="pageTitle">
        <section class="landing-hero">
            <div v-if="status !== 'ok'">
                <h1 class="landing-hero__title">{{ errorTitle }}</h1>
                <p class="landing-hero__subtitle">{{ errorText }}</p>
            </div>

            <div v-else>
                <header class="landing-hero__header">
                    <h1 class="landing-hero__title">{{ headerTitle }}</h1>
                    <p class="landing-hero__subtitle">
                        {{ headerSubtitle }}
                    </p>
                </header>

                <section v-if="isWishlist" class="landing-hero__content">
                    <p class="landing-hero__meta">
                        Список желаний от {{ ownerName }}
                    </p>
                    <ul class="landing-hero__list">
                        <li v-for="wish in wishlist.wishes_preview" :key="wish.id" class="landing-hero__list-item">
                            <span class="landing-hero__item-name">{{ wish.name }}</span>
                        </li>
                    </ul>
                </section>

                <section v-else-if="isShoppingList" class="landing-hero__content">
                    <p class="landing-hero__meta">
                        Список покупок от {{ ownerName }}
                    </p>
                    <ul class="landing-hero__list">
                        <li v-for="item in shoppingList.items_preview" :key="item.id" class="landing-hero__list-item">
                            <span class="landing-hero__item-name"
                                :class="{ 'landing-hero__item-name--done': item.is_purchased }">
                                {{ item.name }}
                            </span>
                        </li>
                    </ul>
                    <p class="landing-hero__meta landing-hero__meta--muted">
                        Всего: {{ shoppingList.items_count }}, куплено: {{ shoppingList.purchased_count }}
                    </p>
                </section>

                <section v-else-if="isWish" class="landing-hero__content">
                    <p class="landing-hero__meta">
                        Желание из списка пользователя {{ ownerName }}
                    </p>
                    <h2 class="landing-hero__wish-name">{{ wish.name }}</h2>
                    <p v-if="wish.description" class="landing-hero__text">{{ wish.description }}</p>
                </section>
            </div>

            <div class="landing-hero__cta">
                <div class="landing-hero__cta-text">
                    Откройте или установите приложение «Что Хочу», чтобы сохранять и редактировать список.
                </div>
                <div class="landing-hero__cta-actions">
                    <a :href="deeplink" class="btn btn-primary">Открыть в приложении</a>
                    <a :href="storeUrl" class="btn btn-secondary">Установить приложение</a>
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

const headerSubtitle = computed(() => {
    if (isWishlist.value) return 'Просмотр списка желаний';
    if (isShoppingList.value) return 'Просмотр списка покупок';
    if (isWish.value) return 'Просмотр желания';
    return '';
});

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
