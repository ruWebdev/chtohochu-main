import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/ui/ui.dart';
import '../providers/wishes_controller.dart';
import 'wish_form_page.dart';

/// Резолвер для маршрута `/wishes/:id/edit`.
///
/// Находит желание по id в загруженном списке и открывает
/// [WishFormPage] в режиме редактирования. Пока список грузится —
/// индикатор; если желание не найдено — empty state с возвратом.
class WishEditPage extends ConsumerWidget {
  const WishEditPage({super.key, required this.wishId});

  final String wishId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(wishesControllerProvider).isLoading;
    final wish = ref.watch(wishByIdProvider(wishId));

    final l10n = context.l10n;

    if (wish != null) {
      return WishFormPage(existing: wish);
    }

    return PopScope(
      // Страница открыта через `go()` — системный Back ведёт к списку
      // желаний, а не закрывает приложение.
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go(AppRoutes.home);
      },
      child: Scaffold(
        backgroundColor: context.appColors.background,
        appBar: AppShellBar(
          leading: AppIconButton(
            icon: const Icon(PhosphorIconsRegular.arrowLeft),
            variant: AppIconButtonVariant.ghost,
            semanticLabel: l10n.back,
            tooltip: l10n.back,
            onPressed: () => context.go(AppRoutes.home),
          ),
        ),
        body: SafeArea(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : Center(
                  child: AppEmptyState(
                    icon: const Icon(PhosphorIconsRegular.magnifyingGlass),
                    title: l10n.wishNotFound,
                    description: l10n.wishNotFoundHint,
                    action: AppButton(
                      label: l10n.backToList,
                      onPressed: () => context.go(AppRoutes.home),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
