import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/ui/ui.dart';
import '../../data/oauth_config.dart';
import '../../domain/oauth_provider.dart';

/// Страница OAuth-авторизации провайдера.
///
/// WebView открывает authorize-URL провайдера; навигационный
/// делегат перехватывает редирект на sentinel `redirectUri`:
/// * VK — authorization code flow + PKCE (`id.vk.ru`): `code`,
///   `device_id` и `state` приходят в query;
/// * Яндекс — implicit: `access_token` и `state` во фрагменте.
///
/// Код/токен не уходит на redirect-сервер (перехват до
/// навигации). Сессия инкогнито: cookies провайдера не
/// персистятся между входами — каждый вход проходит свежее
/// согласие.
///
/// `state` генерируется на открытие и проверяется в ответе —
/// защита от подмены redirect. Для VK дополнительно генерируется
/// PKCE `code_verifier`/`code_challenge` (RFC-7636): код без
/// verifier бесполезен при перехвате.
///
/// Результат — [OAuthCredentials] через `Navigator.pop`;
/// `null` — пользователь закрыл страницу (отмена без ошибки).
class OAuthPage extends StatefulWidget {
  const OAuthPage({super.key, required this.config});

  final OAuthProviderConfig config;

  @override
  State<OAuthPage> createState() => _OAuthPageState();
}

class _OAuthPageState extends State<OAuthPage> {
  static const _verifierChars =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_';

  /// Одноразовый маркер ответа — перевыпускается на каждый retry.
  String _state = const Uuid().v4();

  /// PKCE verifier (только code flow) — остаётся в памяти до
  /// обмена кода на backend.
  String _codeVerifier = _generateVerifier();
  bool _failed = false;
  InAppWebViewController? _controller;

  static String _generateVerifier() {
    final rnd = Random.secure();
    return List.generate(
      64,
      (_) => _verifierChars[rnd.nextInt(_verifierChars.length)],
    ).join();
  }

  static String _challenge(String verifier) =>
      base64Url.encode(sha256.convert(utf8.encode(verifier)).bytes)
          .replaceAll('=', '');

  Uri get _authorizeUri => widget.config.authorizeUri(
        state: _state,
        codeChallenge: widget.config.provider.usesCodeFlow
            ? _challenge(_codeVerifier)
            : null,
      );

  /// Перехват sentinel-редиректа: парсим параметры и завершаем
  /// флоу. Возвращает `true`, если URL относится к redirect URI.
  bool _intercept(Uri url) {
    if (!url.toString().startsWith(widget.config.redirectUri)) {
      return false;
    }
    final credentials = _credentialsFrom(url);
    if (credentials == null) {
      setState(() => _failed = true);
    } else {
      Navigator.of(context).pop(credentials);
    }
    return true;
  }

  /// Разбор redirect-URL в [OAuthCredentials]. `null` — ошибка
  /// провайдера, несовпадение state или отсутствие кода/токена.
  OAuthCredentials? _credentialsFrom(Uri url) {
    if (widget.config.provider.usesCodeFlow) {
      // VK: параметры в query — ?code=…&device_id=…&state=…
      final params = url.queryParameters;
      final code = params['code'];
      final deviceId = params['device_id'];
      if (params.containsKey('error') ||
          params['state'] != _state ||
          code == null ||
          code.isEmpty ||
          deviceId == null ||
          deviceId.isEmpty) {
        return null;
      }
      return OAuthCredentials(
        code: code,
        deviceId: deviceId,
        codeVerifier: _codeVerifier,
        state: _state,
      );
    }

    // Яндекс: параметры во фрагменте — #access_token=…&state=…
    final params = Uri.splitQueryString(url.fragment);
    final token = params['access_token'];
    if (params.containsKey('error') ||
        params['state'] != _state ||
        token == null ||
        token.isEmpty) {
      return null;
    }
    return OAuthCredentials(accessToken: token, state: _state);
  }

  void _retry() {
    setState(() {
      _failed = false;
      _state = const Uuid().v4();
      _codeVerifier = _generateVerifier();
    });
    _controller?.loadUrl(
      urlRequest: URLRequest(url: WebUri.uri(_authorizeUri)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        title: Text(widget.config.label),
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.x),
          tooltip: l10n.close,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: _failed
            ? AppEmptyState(
                icon: const Icon(PhosphorIconsRegular.warningCircle),
                title: l10n.loadFailed,
                description: l10n.pullToRefresh,
                action: AppButton(
                  label: l10n.refresh,
                  onPressed: _retry,
                ),
              )
            : InAppWebView(
                initialSettings: InAppWebViewSettings(incognito: true),
                initialUrlRequest: URLRequest(
                  url: WebUri.uri(_authorizeUri),
                ),
                onWebViewCreated: (controller) => _controller = controller,
                shouldOverrideUrlLoading: (controller, action) async {
                  final url = action.request.url;
                  if (url != null &&
                      action.isForMainFrame != false &&
                      _intercept(url.uriValue)) {
                    return NavigationActionPolicy.CANCEL;
                  }
                  return NavigationActionPolicy.ALLOW;
                },
                onReceivedError: (controller, request, error) {
                  if (request.isForMainFrame != false) {
                    setState(() => _failed = true);
                  }
                },
              ),
      ),
    );
  }
}
