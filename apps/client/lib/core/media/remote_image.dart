import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'media_image_processor.dart';
import 'media_paths.dart';

/// Скачивание внешнего изображения (og:image) в media-пайплайн.
///
/// Не доверяем источнику: лимит размера, таймаут, whitelist
/// content-type. Результат — локальный файл в `Documents/media/wishes`,
/// прошедший [MediaImageProcessor] — дальше штатный upload-флоу
/// ADR-015 (pending → presigned PUT → uploaded).
class RemoteImageFetcher {
  RemoteImageFetcher(this._processor);

  final MediaImageProcessor _processor;

  static const _maxBytes = 8 * 1024 * 1024;
  static const _timeout = Duration(seconds: 15);
  static const _allowedTypes = {'image/jpeg', 'image/png', 'image/webp'};

  /// Скачать [url] и сохранить как фото желания.
  /// Возвращает локальный путь либо `null` — вызывающий код
  /// продолжает без изображения.
  Future<String?> fetchForWish(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.isScheme('https')) return null;

    final client = HttpClient()..connectionTimeout = _timeout;
    File? tmp;
    try {
      final req = await client.getUrl(uri).timeout(_timeout);
      final res = await req.close().timeout(_timeout);
      if (res.statusCode != 200) return null;
      final type = res.headers.contentType;
      if (type == null || !_allowedTypes.contains(type.mimeType)) {
        return null;
      }
      if ((res.headers.contentLength) > _maxBytes) return null;

      final dir = await getTemporaryDirectory();
      tmp = File('${dir.path}/og_${DateTime.now().millisecondsSinceEpoch}');
      final sink = tmp.openWrite();
      var received = 0;
      var overflow = false;
      await for (final chunk in res.timeout(_timeout)) {
        received += chunk.length;
        if (received > _maxBytes) {
          overflow = true;
          break;
        }
        sink.add(chunk);
      }
      await sink.close();
      if (overflow) return null;

      final processed = await _processor.process(
        tmp.path,
        await MediaPaths.wishesDir(),
      );
      return processed.path;
    } catch (_) {
      return null;
    } finally {
      client.close();
      try {
        await tmp?.delete();
      } catch (_) {}
    }
  }
}

final remoteImageFetcherProvider = Provider<RemoteImageFetcher>(
  (ref) => RemoteImageFetcher(ref.read(mediaImageProcessorProvider)),
);
