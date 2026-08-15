import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/notification_store.dart';
import '../data/repository.dart';
import '../domain/models.dart';
import '../domain/notifications.dart';
import 'local_notifications.dart';

class NotificationCoordinator with WidgetsBindingObserver {
  NotificationCoordinator({
    required NotificationStore store,
    required LocalNotificationService notifications,
    required VoidCallback onHistoryChanged,
  })  : _store = store,
        _notifications = notifications,
        _onHistoryChanged = onHistoryChanged;

  final NotificationStore _store;
  final LocalNotificationService _notifications;
  final VoidCallback _onHistoryChanged;

  Timer? _timer;
  DokployRepository? _repository;
  DokployInstance? _instance;
  NotificationPreferences _preferences = const NotificationPreferences();
  bool _busy = false;
  bool _foreground = true;

  void start() => WidgetsBinding.instance.addObserver(this);

  void configure({
    required DokployRepository repository,
    required DokployInstance instance,
    required NotificationPreferences preferences,
  }) {
    final restart = _repository != repository ||
        _instance?.id != instance.id ||
        _preferences.pollSeconds != preferences.pollSeconds ||
        _preferences.enabled != preferences.enabled ||
        _preferences.deliveryMode != preferences.deliveryMode;
    _repository = repository;
    _instance = instance;
    _preferences = preferences;
    if (!restart) return;
    _restartTimer();
  }

  void _restartTimer() {
    _timer?.cancel();
    if (!_shouldPoll) return;
    unawaited(_poll());
    _timer = Timer.periodic(
      Duration(seconds: _preferences.pollSeconds),
      (_) => unawaited(_poll()),
    );
  }

  bool get _shouldPoll =>
      _foreground &&
      (_instance?.demo == false) &&
      _preferences.enabled &&
      _preferences.deliveryMode == NotificationDeliveryMode.polling;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _restartTimer();
  }

  Future<void> _poll() async {
    if (_busy || !_shouldPoll) return;
    final repository = _repository;
    final instance = _instance;
    if (repository == null || instance == null) return;
    _busy = true;
    try {
      final deployments = await repository.deployments();
      final before = await _store.deploymentSnapshot(instance.id);
      final after = {
        for (final deployment in deployments)
          deployment.id: deployment.status.name,
      };
      if (before.isNotEmpty) {
        for (final deployment in deployments) {
          final oldStatus = before[deployment.id];
          if (oldStatus == deployment.status.name) continue;
          final event = DeploymentTransitionDetector.eventFor(
            deployment: deployment,
            previousStatus: oldStatus,
            instanceId: instance.id,
            now: DateTime.now(),
          );
          if (event == null || !_enabledFor(event.kind)) continue;
          await _store.add(event);
          if (!_preferences.isQuietAt(DateTime.now())) {
            await _notifications.show(event);
          }
          _onHistoryChanged();
        }
      }
      await _store.saveDeploymentSnapshot(instance.id, after);
    } catch (_) {
      // Polling must never surface transient network/auth errors over the UI.
      // Normal screens retain their own visible error handling and retry paths.
    } finally {
      _busy = false;
    }
  }

  bool _enabledFor(NotificationEventKind kind) => switch (kind) {
        NotificationEventKind.started => _preferences.notifyStarted,
        NotificationEventKind.succeeded => _preferences.notifySucceeded,
        NotificationEventKind.failed => _preferences.notifyFailed,
      };

  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}

class DeploymentTransitionDetector {
  static NotificationEvent? eventFor({
    required DeploymentModel deployment,
    required String? previousStatus,
    required String instanceId,
    required DateTime now,
  }) {
    final kind = switch (deployment.status) {
      HealthState.deploying => NotificationEventKind.started,
      HealthState.healthy => NotificationEventKind.succeeded,
      HealthState.failed => NotificationEventKind.failed,
      _ => null,
    };
    if (kind == null) return null;
    final service =
        deployment.service.isEmpty ? 'Deployment' : deployment.service;
    final (title, body) = switch (kind) {
      NotificationEventKind.started => (
          'Deployment started',
          '$service is being deployed.'
        ),
      NotificationEventKind.succeeded => (
          'Deployment completed',
          '$service deployed successfully.'
        ),
      NotificationEventKind.failed => (
          'Deployment failed',
          deployment.errorMessage.isEmpty
              ? '$service needs attention.'
              : '$service: ${deployment.errorMessage}'
        ),
    };
    return NotificationEvent(
      id: '${deployment.id}-${deployment.status.name}-${now.microsecondsSinceEpoch}',
      instanceId: instanceId,
      deploymentId: deployment.id,
      kind: kind,
      title: title,
      body: body,
      createdAt: now,
      route: '/deployment/${Uri.encodeComponent(deployment.id)}',
    );
  }
}
