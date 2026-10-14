import 'dart:async';
import 'dart:convert';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Метаданные страницы, извлечённые на устройстве.
///
/// `price` — цена в рублях (целое), `null` если не нашлась
/// в DOM/microdata или не распарсилась.
class LinkPreview {
  const LinkPreview({
    this.title,
    this.description,
    this.imageUrl,
    this.price,
    this.siteName,
  });

  final String? title;
  final String? description;
  final String? imageUrl;
  final int? price;
  final String? siteName;

  bool get isEmpty => title == null && imageUrl == null && description == null;
}

/// Извлекатель OG-метаданных через скрытый WebView.
///
/// Прямые HTTP-запросы к маркетплейсам отклоняются антиботами
/// (WB Guardium — 498, Ozon — 403 + challenge). Реальный движок
/// `HeadlessInAppWebView` исполняет JS-челлендж и дожидается
/// дорендера SPA — проверено на устройстве (WB, Ozon).
///
/// SPA перезаписывает generic-OG реальными уже после загрузки,
/// поэтому результат считается готовым, когда `og:title` не меняется
/// [stablePolls] подряд, либо по таймауту [maxWait].
///
/// Одна активная экстракция на инстанс: повторный [extract]
/// отменяет предыдущий; [cancel] — при закрытии формы.
class LinkPreviewExtractor {
  HeadlessInAppWebView? _headless;
  int _generation = 0;

  /// Извлечь метаданные по [url]. Возвращает `null` при отмене.
  Future<LinkPreview?> extract(
    String url, {
    Duration maxWait = const Duration(seconds: 60),
    int stablePolls = 2,
  }) async {
    final generation = ++_generation;
    await _dispose();

    final loaded = Completer<void>();
    final headless = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url)),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        // Картинки не нужны — экономим трафик и время.
        loadsImagesAutomatically: false,
      ),
      onLoadStop: (c, u) {
        if (!loaded.isCompleted) loaded.complete();
      },
    );
    _headless = headless;

    try {
      await headless.run();
      await loaded.future.timeout(const Duration(seconds: 40));
    } catch (_) {
      // Страница не догрузилась — всё равно читаем DOM, что есть.
    }

    String? lastTitle;
    var stable = 0;
    var ogTitle = '';
    var ogImage = '';
    var ogDesc = '';
    var ogSite = '';
    var domPrice = '';
    final deadline = DateTime.now().add(maxWait);

    while (DateTime.now().isBefore(deadline)) {
      if (_generation != generation || _headless == null) return null;
      await Future.delayed(const Duration(milliseconds: 1500));
      if (_generation != generation || _headless == null) return null;
      try {
        final raw = await headless.webViewController?.evaluateJavascript(
          source: _extractJs,
        );
        if (raw is! String) continue;
        final d = jsonDecode(raw) as Map<String, dynamic>;

        ogTitle = (d['ogTitle'] as String?) ?? ogTitle;
        ogImage = (d['ogImage'] ?? d['twImage'] as String?) ?? ogImage;
        ogDesc = (d['ogDesc'] as String?) ?? ogDesc;
        ogSite = (d['ogSite'] as String?) ?? ogSite;
        domPrice = (d['price'] as String?) ?? domPrice;

        if (d['suspicious'] == true) {
          // Антибот-заглушка — ждём её автоповтор.
          stable = 0;
          continue;
        }
        if (ogTitle.isNotEmpty && ogTitle == lastTitle) {
          if (++stable >= stablePolls) break;
        } else {
          stable = 0;
          lastTitle = ogTitle;
        }
      } catch (_) {
        // WebView мог умереть — выходим с тем, что есть.
        break;
      }
    }

    await _dispose();

    var image = ogImage.isEmpty ? null : ogImage;
    if (image?.startsWith('//') == true) image = 'https:$image';

    return LinkPreview(
      title: ogTitle.isEmpty ? null : ogTitle,
      description: ogDesc.isEmpty ? null : ogDesc,
      imageUrl: image,
      price: parsePrice(domPrice),
      siteName: ogSite.isEmpty ? null : ogSite,
    );
  }

  /// Отменить активную экстракцию (закрытие формы, новый запрос).
  Future<void> cancel() async {
    _generation++;
    await _dispose();
  }

  Future<void> _dispose() async {
    final h = _headless;
    _headless = null;
    try {
      await h?.dispose();
    } catch (_) {}
  }

  /// «3 217 ₽» / «401 ₽» / «3283» → 3217 / 401 / 3283.
  static int? parsePrice(String? raw) {
    if (raw == null) return null;
    final digits = raw.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty || digits.length > 9) return null;
    return int.tryParse(digits);
  }
}

/// Цена: структурированные источники надёжнее DOM-regex.
/// 1) `itemprop=price` (microdata), 2) `product:price:amount` (OG),
/// 3) JSON-LD `Product.offers.price`, 4) первый «N ₽» в поддереве
/// заголовка h1, 5) fallback — первый «N ₽» в body.
///
/// DOM-regex использует только пробелы (в т.ч. неразрывный), но не
/// `\s` — переносы строк не должны склеивать разные числа в одну цену.
const _extractJs = r'''
(function () {
  var T = function (s) {
    var e = document.querySelector(s);
    return e ? (e.content || e.getAttribute('content') || null) : null;
  };
  var price = null;
  var ip = document.querySelector('[itemprop="price"]');
  if (ip) price = ip.getAttribute('content') || ip.innerText;
  if (!price) price = T('meta[property="product:price:amount"]') ||
                     T('meta[name="price"]');
  if (!price) {
    var ss = document.querySelectorAll('script[type="application/ld+json"]');
    for (var i = 0; i < ss.length && !price; i++) {
      try {
        var j = JSON.parse(ss[i].textContent);
        var arr = Array.isArray(j) ? j : (j['@graph'] || [j]);
        for (var k = 0; k < arr.length; k++) {
          var o = arr[k];
          if (o && o['@type'] === 'Product' && o.offers) {
            var off = Array.isArray(o.offers) ? o.offers[0] : o.offers;
            var v = off && (off.price ||
                (off.priceSpecification && off.priceSpecification.price));
            if (v != null) { price = String(v); break; }
          }
        }
      } catch (e) {}
    }
  }
  var re = /[0-9][0-9 \u00A0]{0,9}[ \u00A0]?₽/;
  if (!price) {
    var h1 = document.querySelector('h1');
    var anc = h1 ? h1.parentElement : null;
    for (var n = 0; n < 4 && anc && !price; n++) {
      var m = (anc.innerText || '').match(re);
      if (m) price = m[0];
      anc = anc.parentElement;
    }
  }
  if (!price) {
    var bt = document.body ? document.body.innerText : '';
    price = (bt.match(re) || [null])[0];
  }
  return JSON.stringify({
    ogTitle: T('meta[property="og:title"]'),
    ogImage: T('meta[property="og:image"]'),
    ogDesc: T('meta[property="og:description"]'),
    ogSite: T('meta[property="og:site_name"]'),
    twImage: T('meta[name="twitter:image"]'),
    price: price,
    suspicious: /Подозрительная|Проверяем браузер|captcha|challenge/i
      .test(document.body ? document.body.innerText : '')
  });
})()''';

/// Экстрактор OG — один на приложение: перезапуск extract
/// отменяет предыдущий WebView.
final linkPreviewExtractorProvider = Provider<LinkPreviewExtractor>((ref) {
  final e = LinkPreviewExtractor();
  ref.onDispose(e.cancel);
  return e;
});
