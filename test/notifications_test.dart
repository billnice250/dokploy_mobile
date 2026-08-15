import 'package:dokploy_mobile/core/notification_coordinator.dart';
import 'package:dokploy_mobile/domain/models.dart';
import 'package:dokploy_mobile/domain/notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('quiet hours', () {
    test('supports a range that crosses midnight', () {
      const preferences = NotificationPreferences(
        quietHoursEnabled: true,
        quietStartMinutes: 22 * 60,
        quietEndMinutes: 7 * 60,
      );

      expect(preferences.isQuietAt(DateTime(2026, 8, 15, 23)), isTrue);
      expect(preferences.isQuietAt(DateTime(2026, 8, 15, 6, 59)), isTrue);
      expect(preferences.isQuietAt(DateTime(2026, 8, 15, 12)), isFalse);
    });
  });

  group('deployment transitions', () {
    test('creates a deep-linked failure event', () {
      final now = DateTime(2026, 8, 15, 10);
      final event = DeploymentTransitionDetector.eventFor(
        deployment: DeploymentModel(
          id: 'deploy/123',
          service: 'api',
          status: HealthState.failed,
          createdAt: now,
          errorMessage: 'Build exited with code 1',
        ),
        previousStatus: HealthState.deploying.name,
        instanceId: 'prod',
        now: now,
      );

      expect(event?.kind, NotificationEventKind.failed);
      expect(event?.route, '/deployment/deploy%2F123');
      expect(event?.body, contains('Build exited'));
    });

    test('ignores states that are not alertable', () {
      final event = DeploymentTransitionDetector.eventFor(
        deployment: DeploymentModel(
          id: 'd1',
          service: 'web',
          status: HealthState.stopped,
          createdAt: DateTime(2026),
        ),
        previousStatus: HealthState.healthy.name,
        instanceId: 'prod',
        now: DateTime(2026),
      );

      expect(event, isNull);
    });
  });
}
