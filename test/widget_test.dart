import 'package:dokploy_mobile/app.dart';
import 'package:dokploy_mobile/core/providers.dart';
import 'package:dokploy_mobile/data/mock_repository.dart';
import 'package:dokploy_mobile/domain/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('demo command center renders', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: DokployMobileApp()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Demo Infrastructure'), findsOneWidget);
    expect(find.text('RECENT DEPLOYMENTS'), findsOneWidget);
    expect(find.text('Servers'), findsWidgets);
  });

  testWidgets('unavailable server metrics fit on a compact phone',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWith((ref) => _NoMetricsRepository()),
        ],
        child: const DokployMobileApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.scrollUntilVisible(
      find.text('Monitoring is not configured or has no data yet'),
      450,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
  });
}

class _NoMetricsRepository extends MockDokployRepository {
  @override
  Future<DashboardSnapshot> dashboard() async {
    final original = await super.dashboard();
    return DashboardSnapshot(
      running: original.running,
      stopped: original.stopped,
      failed: original.failed,
      projects: original.projects,
      deployments: original.deployments,
      attention: const [],
      servers: const [
        ServerModel(
          id: 'local',
          name: 'Dokploy host',
          host: '192.0.2.1',
          status: HealthState.healthy,
          cpu: 0,
          memory: 0,
          disk: 0,
          metricsAvailable: false,
        ),
      ],
    );
  }
}
