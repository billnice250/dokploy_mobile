import 'package:dokploy_mobile/app.dart';
import 'package:dokploy_mobile/core/providers.dart';
import 'package:dokploy_mobile/core/router.dart';
import 'package:dokploy_mobile/data/mock_repository.dart';
import 'package:dokploy_mobile/domain/models.dart';
import 'package:dokploy_mobile/screens/service_detail.dart';
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

  testWidgets('glass navigation fits on a narrow phone', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    router.go('/projects');
    addTearDown(() {
      router.go('/');
      tester.binding.setSurfaceSize(null);
    });
    await tester.pumpWidget(
      const ProviderScope(child: DokployMobileApp()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Projects'), findsWidgets);
    expect(find.text('Activity'), findsWidgets);
    expect(find.text('Servers'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unconfigured real server offers monitoring and cleanup',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    router.go('/servers');
    addTearDown(() {
      router.go('/');
      tester.binding.setSurfaceSize(null);
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentInstanceProvider.overrideWith(
            (ref) => const DokployInstance(
              id: 'production',
              name: 'Production',
              baseUrl: 'https://dokploy.example.com',
            ),
          ),
          repositoryProvider.overrideWith((ref) => _NoMetricsRepository()),
        ],
        child: const DokployMobileApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Monitoring is not enabled'), findsOneWidget);
    expect(find.text('Enable monitoring'), findsOneWidget);
    expect(find.text('Clear unused storage'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('service detail renders container units and runtime metadata',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWith((ref) => _MetricRepository()),
        ],
        child: const MaterialApp(
          home: ServiceDetailScreen(serviceId: 'ollama'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('401.6%'), findsOneWidget);
    expect(find.text('7.37 GB'), findsOneWidget);
    expect(find.text('Received'), findsOneWidget);
    expect(find.text('10.4 MB'), findsOneWidget);
    expect(find.text('Sent'), findsOneWidget);
    expect(find.text('3.7 MB'), findsOneWidget);
    expect(find.text('ollama/ollama:latest'), findsOneWidget);
    expect(find.text('The latest sample is stale'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _MetricRepository extends MockDokployRepository {
  static const listed = ServiceModel(
    id: 'ollama',
    name: 'ollama',
    kind: ServiceKind.application,
    status: HealthState.healthy,
    metricsAvailable: false,
  );

  @override
  Future<List<ServiceModel>> services() async => const [listed];

  @override
  Future<ServiceModel> serviceDetails(ServiceModel service) async =>
      service.copyWith(
        image: 'ollama/ollama:latest',
        appName: 'internal-applications-ollama-mx5teo',
        cpu: 401.55,
        memoryMb: 7.368 * 1024,
        networkReceivedMb: 10.4,
        networkSentMb: 3.73,
        metricsAvailable: true,
        metricsUpdatedAt: DateTime.utc(2026, 6, 18, 9, 22),
      );
}

class _NoMetricsRepository extends MockDokployRepository {
  @override
  Future<List<ServerModel>> servers() async => const [
        ServerModel(
          id: 'local',
          name: 'Dokploy host',
          host: '192.0.2.1',
          status: HealthState.healthy,
          cpu: 0,
          memory: 0,
          disk: 0,
          metricsAvailable: false,
          monitoringConfigured: false,
        ),
      ];

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
