import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../domain/shared_content.dart';

/// Capability-ссылка на share — ответ `POST .../share`.
///
/// `id`/`shareable_id` сервер не отдаёт: для клиента share
/// существует как URL.
class ShareLink {
  const ShareLink({required this.token, required this.url});

  factory ShareLink.fromJson(Map<String, dynamic> json) =>
      ShareLink(token: json['token'] as String, url: json['url'] as String);

  final String token;
  final String url;
}

/// HTTP-контракт Sharing.
///
/// Online-only по MVP-контракту: shares НЕ ходят через
/// Drift/outbox/SyncEngine — без сети ссылки физически не
/// существует. Token генерируется только backend'ом.
class ShareApi {
  const ShareApi(this._dio);

  final Dio _dio;

  /// Создать (или вернуть существующий активный) share желания.
  Future<ShareLink> createWishShare(String wishId) =>
      _create('/wishes/$wishId/share');

  /// Создать (или вернуть существующий активный) share списка.
  Future<ShareLink> createWishListShare(String listId) =>
      _create('/wish-lists/$listId/share');

  /// Отозвать share (idempotent — повторный вызов безопасен).
  Future<void> revokeShare(String shareId) =>
      _dio.delete<void>('/shares/$shareId');

  /// Публичный resolver по capability-токену → типизированная
  /// публичная проекция (`SharedContent`). Auth-заголовок не нужен —
  /// интерцептор навесит Bearer только если он есть.
  Future<SharedContent> getPublicShare(String token) async {
    final res = await _dio.get<Map<String, dynamic>>('/share/$token');
    return SharedContent.fromJson(res.data ?? const <String, dynamic>{});
  }

  Future<ShareLink> _create(String path) async {
    final res = await _dio.post<Map<String, dynamic>>(path);
    return ShareLink.fromJson(res.data!['data'] as Map<String, dynamic>);
  }
}

final shareApiProvider = Provider<ShareApi>(
  (ref) => ShareApi(ref.read(apiClientProvider)),
);

/// Публичный share-контент по capability-токену — единственный
/// источник данных для `/s/:token`. Online-only: viewer не пишет
/// ни в Drift, ни в outbox.
final sharedContentProvider = FutureProvider.autoDispose
    .family<SharedContent, String>(
      (ref, token) => ref.read(shareApiProvider).getPublicShare(token),
      // Без авто-retry: 404 и сетевые ошибки показываются сразу,
      // повтор — только по кнопке «Повторить» (ref.invalidate).
      retry: (retryCount, error) => null,
    );
