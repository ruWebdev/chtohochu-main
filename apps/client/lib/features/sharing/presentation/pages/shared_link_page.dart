import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/ui/ui.dart';
import '../../data/share_api.dart';
import '../../domain/shared_content.dart';
import 'shared_wish_list_page.dart';
import 'shared_wish_page.dart';

/// Публичный read-only viewer share-ссылки `/s/{token}`.
///
/// Единственный источник данных — публичный `GET /share/{token}`
/// (online-only). Страница не пишет в Drift/outbox и не участвует
/// в sync: просмотр чужого контента ничего не создаёт локально.
///
/// Состояния:
/// * loading → индикатор;
/// * 404 (invalid/revoked/expired/deleted) → единое «ссылка
///   недействительна» — причина не раскрывается;
/// * прочие ошибки → «не удалось загрузить» + «Повторить».
class SharedLinkPage extends ConsumerWidget {
  const SharedLinkPage({super.key, required this.token});

  /// Capability-токен из URL — не UUID сущности.
  final String token;

  void _back(BuildContext context) {
    // Deep link: стек может быть пуст → на главную, иначе pop.
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(sharedContentProvider(token));

    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back(context);
      },
      child: Scaffold(
        backgroundColor: context.appColors.background,
        appBar: AppShellBar(
          title: l10n.appName,
          leading: AppIconButton(
            icon: const Icon(PhosphorIconsRegular.arrowLeft),
            variant: AppIconButtonVariant.ghost,
            semanticLabel: l10n.back,
            tooltip: l10n.back,
            onPressed: () => _back(context),
          ),
        ),
        body: SafeArea(
          child: switch (async) {
            AsyncData(:final value) => switch (value) {
              SharedWish w => SharedWishPage(wish: w),
              SharedWishList l => SharedWishListPage(list: l),
            },
            AsyncError(:final error) => _ShareError(
              invalid: _isNotFound(error),
              onRetry: () => ref.invalidate(sharedContentProvider(token)),
            ),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      ),
    );
  }

  /// Единая public-capability-граница: backend отдаёт одинаковый 404
  /// для invalid/revoked/expired/deleted — не различаем причину.
  bool _isNotFound(Object error) =>
      error is DioException && error.response?.statusCode == 404;
}

/// Состояние ошибки: 404 → «ссылка недействительна», остальное →
/// «не удалось загрузить» + retry.
class _ShareError extends StatelessWidget {
  const _ShareError({required this.invalid, required this.onRetry});

  final bool invalid;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: AppEmptyState(
        icon: Icon(
          invalid
              ? PhosphorIconsRegular.linkBreak
              : PhosphorIconsRegular.cloudSlash,
        ),
        title: invalid ? l10n.shareInvalidTitle : l10n.loadFailed,
        description: invalid
            ? l10n.shareInvalidDescription
            : l10n.shareLoadErrorDescription,
        action: invalid
            ? null
            : AppButton(label: l10n.retry, onPressed: onRetry),
      ),
    );
  }
}
