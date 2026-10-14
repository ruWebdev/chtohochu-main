import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/ui/ui.dart';
import '../../data/oauth_config.dart';
import '../../domain/oauth_provider.dart';

/// Страница OAuth-авторизации провайдера (implicit token flow).
///
/// WebView открывает authorize-URL провайдера; навигационный
/// делегат перехватывает редирект на sentinel `redirectUri` и
/// извлекает `access_token` из URL-фрагмента — токен не уходит
/// на redirect-сервер и недоступен JS на странице
/// (docs/20-backend/oauth.md §7). Сессия инкогнито: cookies
/// провайдера не персистятся между входами — каждый вход
/// проходит свежее согласие.
///
/// `state` генерируется на открытие и проверяется в ответе —
/// защита от подмены redirect. Ответ без `state` или с чужим
/// `state` считается ошибкой.
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
  /// Одноразовый маркер ответа — перевыпускается на каждый retry.
  String _state = const Uuid().v4();
  bool _failed = false;
  InAppWebViewController? _controller;

  Uri get _authorizeUri => widget.config.authorizeUri(state: _state);

  /// Перехват sentinel-редиректа: парсим фрагмент и завершаем
  /// флоу. Возвращает `true`, если URL относится к redirect URI.
  bool _intercept(Uri url) {
    if (!url.toString().startsWith(widget.config.redirectUri)) {
      return false;
    }
    final params = Uri.splitQueryString(url.fragment);
    final token = params['access_token'];
    if (params.containsKey('error') ||
        params['state'] != _state ||
        token == null ||
        token.isEmpty) {
      setState(() => _failed = true);
    } else {
      Navigator.of(
        context,
      ).pop(OAuthCredentials(accessToken: token, email: params['email']));
    }
    return true;
  }

  void _retry() {
    setState(() {
      _failed = false;
      _state = const Uuid().v4();
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
