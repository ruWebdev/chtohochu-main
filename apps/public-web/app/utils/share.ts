/**
 * Типы и хелперы публичного share-viewer'а `/s/[token]`.
 *
 * Формат данных — контракт backend `GET /api/v1/share/{token}`
 * (SharedWishResource / SharedWishListResource). Только публичная
 * проекция: id, owner_id, list_id, note, timestamps и sync-поля
 * сюда не приходят и не рендерятся.
 *
 * Файл намеренно без Vue/Nuxt-зависимостей — хелперы покрыты
 * node:test без дополнительного фреймворка.
 */

export interface SharedWish {
  title: string;
  price: number | null;
  link: string | null;
  image_url: string | null;
  /** В списке желаний owner у элементов не подгружается. */
  owner?: { name: string | null } | null;
}

export interface SharedWishList {
  title: string;
  owner: { name: string | null };
  wishes: SharedWish[];
}

export type ShareResponse =
  | { type: 'wish'; data: SharedWish }
  | { type: 'wish_list'; data: SharedWishList };

/** «12 990 ₽» — тот же формат, что в приложении. null → null. */
export function formatWishPrice(
  price: number | null | undefined,
): string | null {
  if (price == null) return null;
  return `${new Intl.NumberFormat('ru-RU').format(price)} ₽`;
}

/** `<title>` и og:title: «Наушники — ЧтоХочу». */
export function sharePageTitle(response: ShareResponse): string {
  return `${response.data.title} — ЧтоХочу`;
}

/** meta description и og:description. */
export function sharePageDescription(response: ShareResponse): string {
  if (response.type === 'wish') {
    const name = response.data.owner?.name ?? 'Пользователь';
    return `${name} хочет: ${response.data.title}`;
  }
  const name = response.data.owner.name ?? 'Пользователь';
  return `${name}: список желаний «${response.data.title}»`;
}

/**
 * og:image — image_url желания; для списка — первое доступное
 * изображение желания. null → og:image не выставляется.
 */
export function shareOgImage(response: ShareResponse): string | null {
  if (response.type === 'wish') return response.data.image_url;
  return (
    response.data.wishes.find((w) => w.image_url != null)?.image_url ?? null
  );
}

/** Безопасный ли URL для внешней кнопки «Открыть товар» (http/https). */
export function isSafeExternalLink(link: string | null | undefined): boolean {
  if (link == null) return false;
  try {
    const url = new URL(link);
    return url.protocol === 'https:' || url.protocol === 'http:';
  } catch {
    return false;
  }
}
