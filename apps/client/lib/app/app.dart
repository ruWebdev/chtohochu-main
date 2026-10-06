import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_info.dart';
import '../core/realtime/realtime_client.dart';
import '../core/sync/sync_engine.dart';
import '../l10n/l10n.dart';
import '../features/showcase/presentation/providers/theme_controller.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

/// Корневой виджет приложения.
class ChtoHochuApp extends ConsumerStatefulWidget {
  const ChtoHochuApp({super.key});

  @override
  ConsumerState<ChtoHochuApp> createState() => _ChtoHochuAppState();
}

class _ChtoHochuAppState extends ConsumerState<ChtoHochuApp> {
  late final SyncLifecycleObserver _syncObserver;
  late final RealtimeLifecycleObserver _realtimeObserver;

  @override
  void initState() {
    super.initState();
    // Sync по возврату приложения в foreground.
    _syncObserver = ref.read(syncLifecycleObserverProvider);
    WidgetsBinding.instance.addObserver(_syncObserver);
    // Досоединение WebSocket по возврату в foreground.
    _realtimeObserver = ref.read(realtimeLifecycleObserverProvider);
    WidgetsBinding.instance.addObserver(_realtimeObserver);
    // Держим engine живым на всю сессию.
    ref.read(syncEngineProvider);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_syncObserver);
    WidgetsBinding.instance.removeObserver(_realtimeObserver);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      // ru — единственный доступный язык; пинним явно, чтобы
      // системная локаль устройства ничего не переключала.
      locale: const Locale('ru'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: router,
    );
  }
}
