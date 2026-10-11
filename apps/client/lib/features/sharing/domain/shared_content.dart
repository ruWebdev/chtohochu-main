/// Публичные DTO share-viewer'а — контракт `GET /api/v1/share/{token}`
/// (SharedWishResource / SharedWishListResource).
///
/// Намеренно отдельные от `Wish`/`WishList`: публичная проекция
/// содержит только безопасные поля — никаких id, owner_id, list_id,
/// note, timestamps и sync-полей здесь не существует.
sealed class SharedContent {
  const SharedContent();

  /// `{type, data}` → типизированная модель.
  factory SharedContent.fromJson(Map<String, dynamic> json) {
    return switch (json['type']) {
      'wish' => SharedWish.fromJson(json['data'] as Map<String, dynamic>),
      'wish_list' => SharedWishList.fromJson(
        json['data'] as Map<String, dynamic>,
      ),
      _ => throw const FormatException('Unknown shared content type'),
    };
  }
}

/// Публичная проекция желания: title, price, link, image_url, owner.name.
class SharedWish extends SharedContent {
  const SharedWish({
    required this.title,
    this.price,
    this.link,
    this.imageUrl,
    this.ownerName,
  });

  factory SharedWish.fromJson(Map<String, dynamic> json) => SharedWish(
    title: json['title'] as String,
    price: json['price'] as int?,
    link: json['link'] as String?,
    imageUrl: json['image_url'] as String?,
    ownerName: (json['owner'] as Map<String, dynamic>?)?['name'] as String?,
  );

  final String title;
  final int? price;
  final String? link;
  final String? imageUrl;
  final String? ownerName;
}

/// Публичная проекция списка желаний: title, owner.name, wishes.
class SharedWishList extends SharedContent {
  const SharedWishList({
    required this.title,
    this.ownerName,
    required this.wishes,
  });

  factory SharedWishList.fromJson(Map<String, dynamic> json) => SharedWishList(
    title: json['title'] as String,
    ownerName: (json['owner'] as Map<String, dynamic>?)?['name'] as String?,
    wishes: [
      for (final w in (json['wishes'] as List<dynamic>? ?? const []))
        SharedWish.fromJson(w as Map<String, dynamic>),
    ],
  );

  final String title;
  final String? ownerName;
  final List<SharedWish> wishes;
}
