import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/notifications.dart';

class NotificationStore {
  const NotificationStore();

  static const _historyKey = 'notification.history.v1';
  static const _maxHistory = 100;

  Future<NotificationPreferences> preferences(String instanceId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('notification.preferences.$instanceId');
    if (raw == null) return const NotificationPreferences();
    try {
      return NotificationPreferences.fromJson(
        Map<String, Object?>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return const NotificationPreferences();
    }
  }

  Future<void> savePreferences(
    String instanceId,
    NotificationPreferences value,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'notification.preferences.$instanceId',
      jsonEncode(value.toJson()),
    );
  }

  Future<Map<String, String>> deploymentSnapshot(String instanceId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('notification.deployments.$instanceId');
    if (raw == null) return {};
    try {
      return Map<String, String>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  Future<void> saveDeploymentSnapshot(
    String instanceId,
    Map<String, String> snapshot,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'notification.deployments.$instanceId',
      jsonEncode(snapshot),
    );
  }

  Future<List<NotificationEvent>> history({String? instanceId}) async {
    final prefs = await SharedPreferences.getInstance();
    final items = prefs.getStringList(_historyKey) ?? const [];
    final events = <NotificationEvent>[];
    for (final item in items) {
      try {
        final event = NotificationEvent.fromJson(
          Map<String, Object?>.from(jsonDecode(item) as Map),
        );
        if (instanceId == null || event.instanceId == instanceId) {
          events.add(event);
        }
      } catch (_) {
        // Ignore a corrupt local row without losing the rest of the history.
      }
    }
    return events;
  }

  Future<void> add(NotificationEvent event) async {
    final prefs = await SharedPreferences.getInstance();
    final items = prefs.getStringList(_historyKey) ?? <String>[];
    final next =
        [jsonEncode(event.toJson()), ...items].take(_maxHistory).toList();
    await prefs.setStringList(_historyKey, next);
  }

  Future<void> markRead(String id) async => _rewrite(
        (event) => event.id == id ? event.copyWith(read: true) : event,
      );

  Future<void> markAllRead({String? instanceId}) async => _rewrite(
        (event) => instanceId == null || event.instanceId == instanceId
            ? event.copyWith(read: true)
            : event,
      );

  Future<void> _rewrite(
    NotificationEvent Function(NotificationEvent) transform,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final items = prefs.getStringList(_historyKey) ?? const [];
    final next = <String>[];
    for (final item in items) {
      try {
        final event = NotificationEvent.fromJson(
          Map<String, Object?>.from(jsonDecode(item) as Map),
        );
        next.add(jsonEncode(transform(event).toJson()));
      } catch (_) {
        next.add(item);
      }
    }
    await prefs.setStringList(_historyKey, next);
  }
}
