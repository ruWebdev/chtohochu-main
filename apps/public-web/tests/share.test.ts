import assert from 'node:assert/strict';
import test from 'node:test';

import {
  formatWishPrice,
  isSafeExternalLink,
  shareOgImage,
  sharePageDescription,
  sharePageTitle,
  type ShareResponse,
// Явное .ts — node --test резолвит ESM без расширений бандлера.
} from '../app/utils/share.ts';

const wish: ShareResponse = {
  type: 'wish',
  data: {
    title: 'Наушники Sony',
    price: 12990,
    link: 'https://example.com/sony',
    image_url: 'https://s3.example.com/chtohochu-wish-images/x.jpg',
    owner: { name: 'Наташа' },
  },
};

const list: ShareResponse = {
  type: 'wish_list',
  data: {
    title: 'Техника',
    owner: { name: 'Наташа' },
    wishes: [
      { title: 'MacBook Air', price: 99990, link: null, image_url: null },
      {
        title: 'Монитор',
        price: 25000,
        link: 'https://example.com/m',
        image_url: 'https://s3.example.com/chtohochu-wish-images/m.jpg',
      },
    ],
  },
};

test('formatWishPrice: цена в формате приложения, null → null', () => {
  assert.equal(formatWishPrice(12990)!.replace(/ /g, ' '), '12 990 ₽');
  assert.equal(formatWishPrice(0)!.replace(/ /g, ' '), '0 ₽');
  assert.equal(formatWishPrice(null), null);
  assert.equal(formatWishPrice(undefined), null);
});

test('sharePageTitle: «Название — ЧтоХочу» для обоих типов', () => {
  assert.equal(sharePageTitle(wish), 'Наушники Sony — ЧтоХочу');
  assert.equal(sharePageTitle(list), 'Техника — ЧтоХочу');
});

test('sharePageDescription: wish — «имя хочет: title»', () => {
  assert.equal(sharePageDescription(wish), 'Наташа хочет: Наушники Sony');
});

test('sharePageDescription: wish_list — имя + название списка', () => {
  assert.equal(
    sharePageDescription(list),
    'Наташа: список желаний «Техника»',
  );
});

test('sharePageDescription: без имени — fallback «Пользователь»', () => {
  const noOwner: ShareResponse = {
    type: 'wish',
    data: { ...wish.data, owner: null },
  };
  assert.equal(sharePageDescription(noOwner), 'Пользователь хочет: Наушники Sony');
});

test('shareOgImage: wish — image_url, null → null', () => {
  assert.equal(
    shareOgImage(wish),
    'https://s3.example.com/chtohochu-wish-images/x.jpg',
  );
  const noImage: ShareResponse = {
    type: 'wish',
    data: { ...wish.data, image_url: null },
  };
  assert.equal(shareOgImage(noImage), null);
});

test('shareOgImage: wish_list — первое доступное изображение', () => {
  assert.equal(
    shareOgImage(list),
    'https://s3.example.com/chtohochu-wish-images/m.jpg',
  );
  const empty: ShareResponse = {
    type: 'wish_list',
    data: { ...list.data, wishes: [] },
  };
  assert.equal(shareOgImage(empty), null);
});

test('isSafeExternalLink: только http/https', () => {
  assert.equal(isSafeExternalLink('https://example.com'), true);
  assert.equal(isSafeExternalLink('http://example.com'), true);
  assert.equal(isSafeExternalLink(null), false);
  assert.equal(isSafeExternalLink('javascript:alert(1)'), false);
  assert.equal(isSafeExternalLink('не ссылка'), false);
});
