import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';

/// Инструкции на загрузку объекта от backend
/// (`POST /media/uploads`, ADR-015).
class MediaUploadInstructions {
  const MediaUploadInstructions({
    required this.uploadId,
    required this.uploadUrl,
    required this.headers,
    required this.objectKey,
    required this.remoteUrl,
    required this.expiresAt,
  });

  final String uploadId;
  final String uploadUrl;

  /// Подписанные заголовки — клиент ОБЯЗАН передать их с PUT
  /// (Content-Type в том числе — без него объект получит дефолтный
  /// MIME и не пройдёт серверный complete).
  final Map<String, String> headers;
  final String objectKey;
  final String remoteUrl;
  final DateTime expiresAt;
}

/// Отправка объекта по presigned PUT.
///
/// Выделено в typedef: тесты подменяют транспорт, не подменяя
/// сам сервис — вся логика request→put→complete остаётся реальной.
typedef MediaObjectPut =
    Future<void> Function(String url, Map<String, String> headers, File file);

/// Media upload pipeline (ADR-015):
///
/// ```
/// requestUpload  → presigned PUT (S3) → complete → remote_url
/// ```
///
/// Сервис отделён от `WishRepository`: репозиторий владеет Drift,
/// этот сервис — сетевым upload lifecycle. Идемпотентность через
/// `client_id` — повтор запроса инструкций возвращает тот же upload.
class MediaUploadService {
  MediaUploadService({required this.api, MediaObjectPut? put})
    : _put = put ?? _defaultPut;

  final Dio api;
  final MediaObjectPut _put;

  /// Инструкции на загрузку. `clientId` — стабильный id локальной
  /// сущности изображения → retry не плодит дубликаты объектов.
  Future<MediaUploadInstructions> requestUpload({
    required String purpose,
    String? entityId,
    required String contentType,
    required int size,
    String? clientId,
  }) async {
    final res = await api.post<Map<String, dynamic>>(
      '/media/uploads',
      data: {
        'purpose': purpose,
        'entity_id': entityId,
        'content_type': contentType,
        'size': size,
        'client_id': clientId,
      },
    );
    final data = res.data!['data'] as Map<String, dynamic>;
    return MediaUploadInstructions(
      uploadId: data['upload_id'] as String,
      uploadUrl: data['upload_url'] as String,
      headers: {
        for (final e in (data['upload_headers'] as Map? ?? const {}).entries)
          e.key as String: e.value as String,
      },
      objectKey: data['object_key'] as String,
      remoteUrl: data['remote_url'] as String,
      expiresAt: DateTime.parse(data['expires_at'] as String),
    );
  }

  /// PUT файла по presigned URL + подтверждение → remote_url.
  Future<String> uploadAndConfirm(
    MediaUploadInstructions instructions,
    File file,
  ) async {
    await _put(instructions.uploadUrl, instructions.headers, file);
    final res = await api.post<Map<String, dynamic>>(
      '/media/uploads/${instructions.uploadId}/complete',
    );
    return (res.data!['data'] as Map<String, dynamic>)['remote_url'] as String;
  }

  /// Отдельный Dio без auth/baseUrl — presigned URL абсолютный,
  /// подпись уже несёт авторизацию.
  static Future<void> _defaultPut(
    String url,
    Map<String, String> headers,
    File file,
  ) {
    final dio = Dio();
    return dio.put<void>(
      url,
      data: file.openRead(),
      options: Options(
        headers: {...headers, Headers.contentLengthHeader: file.lengthSync()},
      ),
    );
  }
}

final mediaUploadServiceProvider = Provider<MediaUploadService>(
  (ref) => MediaUploadService(api: ref.read(apiClientProvider)),
);
