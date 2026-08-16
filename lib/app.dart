import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/local_notifications.dart';
import 'core/live_data_coordinator.dart';
import 'core/notification_coordinator.dart';
import 'core/providers.dart';
import 'core/router.dart';
import 'core/theme.dart';

class DokployMobileApp extends ConsumerStatefulWidget {
  const DokployMobileApp({super.key});

  @override
  ConsumerState<DokployMobileApp> createState() => _DokployMobileAppState();
}

class _DokployMobileAppState extends ConsumerState<DokployMobileApp> {
  late final NotificationCoordinator _coordinator;
  late final LiveDataCoordinator _liveData;
  StreamSubscription<String>? _routeSubscription;

  @override
  void initState() {
    super.initState();
    _coordinator = NotificationCoordinator(
      store: ref.read(notificationStoreProvider),
      notifications: LocalNotificationService.instance,
      onHistoryChanged: () {
        final id = ref.read(currentInstanceProvider).id;
        ref.invalidate(notificationHistoryProvider(id));
      },
    )..start();
    _liveData = LiveDataCoordinator(
      onRefresh: ({required includeInfrastructure}) {
        if (!mounted) return;
        ref.invalidate(dashboardProvider);
        ref.invalidate(servicesProvider);
        ref.invalidate(deploymentsProvider);
        ref.invalidate(serviceDetailProvider);
        ref.invalidate(traefikRequestsProvider);
        if (includeInfrastructure) ref.invalidate(serversProvider);
      },
    )..start();
    _routeSubscription =
        LocalNotificationService.instance.routes.listen(router.go);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initialRoute = LocalNotificationService.instance.takeInitialRoute();
      if (initialRoute != null) router.go(initialRoute);
    });
  }

  @override
  void dispose() {
    _routeSubscription?.cancel();
    _coordinator.dispose();
    _liveData.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final instance = ref.watch(currentInstanceProvider);
    final repository = ref.watch(repositoryProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _liveData.configure(enabled: !instance.demo);
    });
    final preferences =
        ref.watch(notificationPreferencesProvider(instance.id)).valueOrNull;
    if (preferences != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _coordinator.configure(
          repository: repository,
          instance: instance,
          preferences: preferences,
        );
      });
    }
    return MaterialApp.router(
      title: 'DployGo',
      debugShowCheckedModeBanner: false,
      theme: DokployTheme.light,
      darkTheme: DokployTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
