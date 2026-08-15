import 'dart:async';
import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../domain/notifications.dart';

class LocalNotificationService {
  LocalNotificationService._();

  static final instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<String> _routes = StreamController.broadcast();
  bool _initialized = false;
  String? _initialRoute;

  Stream<String> get routes => _routes.stream;

  String? takeInitialRoute() {
    final route = _initialRoute;
    _initialRoute = null;
    return route;
  }

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final route = response.payload;
        if (route != null && route.startsWith('/')) _routes.add(route);
      },
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      final payload = launch?.notificationResponse?.payload;
      if (payload != null && payload.startsWith('/')) _initialRoute = payload;
    }
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    if (Platform.isIOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    if (Platform.isAndroid) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          false;
    }
    return false;
  }

  Future<void> show(NotificationEvent event) async {
    if (!_initialized || kIsWeb) return;
    final isFailure = event.kind == NotificationEventKind.failed;
    final channel = isFailure ? 'deployment_failures' : 'deployments';
    final android = AndroidNotificationDetails(
      channel,
      isFailure ? 'Deployment failures' : 'Deployments',
      channelDescription: 'Dokploy deployment status changes',
      importance: Importance.high,
      priority: Priority.high,
      color: isFailure ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
    );
    await _plugin.show(
      id: event.id.hashCode & 0x7fffffff,
      title: event.title,
      body: event.body,
      notificationDetails: NotificationDetails(
        android: android,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: event.route,
    );
  }
}
