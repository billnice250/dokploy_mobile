import 'repository.dart';
import '../domain/models.dart';

class MockDokployRepository implements DokployRepository {
  static final now = DateTime.now();
  final _projects = const [
    ProjectModel(
        id: 'p1',
        name: 'Production',
        description: 'Core production workloads',
        environmentCount: 2,
        serviceCount: 9),
    ProjectModel(
        id: 'p2',
        name: 'Media',
        description: 'Home media stack',
        environmentCount: 1,
        serviceCount: 6),
    ProjectModel(
        id: 'p3',
        name: 'Staging',
        description: 'Pre-production',
        environmentCount: 2,
        serviceCount: 4),
  ];
  final _services = const [
    ServiceModel(
        id: 'a1',
        name: 'PKI Server',
        kind: ServiceKind.application,
        status: HealthState.healthy,
        project: 'Production',
        image: 'registry/pki-server:latest',
        domain: 'pki.example.com',
        cpu: 4.2,
        memoryMb: 287,
        networkReceivedMb: 1.4,
        networkSentMb: .3,
        appName: 'pki-server'),
    ServiceModel(
        id: 'c1',
        name: 'Media Stack',
        kind: ServiceKind.compose,
        status: HealthState.healthy,
        project: 'Media',
        image: 'docker-compose',
        domain: 'media.example.com',
        cpu: 18,
        memoryMb: 1240,
        networkReceivedMb: 24,
        networkSentMb: 1.8,
        appName: 'media-stack'),
    ServiceModel(
        id: 'a2',
        name: 'Auth Server',
        kind: ServiceKind.application,
        status: HealthState.deploying,
        project: 'Production',
        image: 'registry/auth-server:1.2.29',
        domain: 'auth.example.com',
        cpu: 7.1,
        memoryMb: 410,
        appName: 'auth-server'),
    ServiceModel(
        id: 'a3',
        name: 'Cloudflared',
        kind: ServiceKind.application,
        status: HealthState.healthy,
        project: 'Media',
        image: 'cloudflare/cloudflared:latest',
        cpu: .6,
        memoryMb: 32,
        appName: 'cloudflared'),
    ServiceModel(
        id: 'db1',
        name: 'Main PostgreSQL',
        kind: ServiceKind.postgres,
        status: HealthState.healthy,
        project: 'Production',
        image: 'postgres:17',
        cpu: 12,
        memoryMb: 620,
        appName: 'postgres'),
    ServiceModel(
        id: 'a4',
        name: 'Worker',
        kind: ServiceKind.application,
        status: HealthState.failed,
        project: 'Staging',
        image: 'registry/worker:edge',
        cpu: 0,
        memoryMb: 0,
        appName: 'worker'),
  ];

  @override
  Future<CapabilitySet> capabilities() async => CapabilitySet.demo;

  @override
  Future<DashboardSnapshot> dashboard() async => DashboardSnapshot(
          running: 17,
          stopped: 2,
          failed: 1,
          projects: _projects,
          deployments: await deployments(),
          servers: await servers(),
          attention: const [
            'Staging Worker deployment failed',
            'Home server disk usage is 82%',
            'Dokploy backup has not run in 3 days'
          ]);
  @override
  Future<List<ProjectModel>> projects() async => _projects;
  @override
  Future<List<ServiceModel>> services() async => _services;
  @override
  Future<ServiceModel> serviceDetails(ServiceModel service) async => service;
  @override
  Future<List<DeploymentModel>> deployments() async => [
        DeploymentModel(
            id: 'd1',
            service: 'Auth Server',
            serviceId: 'a2',
            status: HealthState.deploying,
            createdAt: now.subtract(const Duration(minutes: 2)),
            startedAt: now.subtract(const Duration(minutes: 2)),
            commit: 'a813bc4',
            title: 'Manual deployment',
            message: 'Release 1.2.29',
            durationSeconds: 134),
        DeploymentModel(
            id: 'd2',
            service: 'PKI Server',
            serviceId: 'a1',
            status: HealthState.healthy,
            createdAt: now.subtract(const Duration(minutes: 18)),
            startedAt: now.subtract(const Duration(minutes: 18)),
            finishedAt: now.subtract(const Duration(minutes: 17)),
            commit: 'dc934ab',
            title: 'Git push',
            message: 'Fix OIDC callback',
            durationSeconds: 73),
        DeploymentModel(
            id: 'd3',
            service: 'Worker',
            serviceId: 'a4',
            status: HealthState.failed,
            createdAt: now.subtract(const Duration(hours: 1)),
            startedAt: now.subtract(const Duration(hours: 1)),
            finishedAt: now.subtract(const Duration(hours: 1, minutes: -2)),
            commit: '72df91a',
            branch: 'staging',
            title: 'Git push',
            errorMessage: 'Container health check failed',
            message: 'Update queue processor',
            durationSeconds: 103),
      ];
  @override
  Future<List<ServerModel>> servers() async => const [
        ServerModel(
            id: 's1',
            name: 'Home',
            host: 'home.example.com',
            status: HealthState.healthy,
            cpu: 18,
            memory: 61,
            disk: 82),
        ServerModel(
            id: 's2',
            name: 'Production EU',
            host: 'prod-eu.example.com',
            status: HealthState.healthy,
            cpu: 34,
            memory: 54,
            disk: 48),
        ServerModel(
            id: 's3',
            name: 'Staging',
            host: 'staging.example.com',
            status: HealthState.healthy,
            cpu: 12,
            memory: 37,
            disk: 31),
      ];
  @override
  Future<List<BackupModel>> backups() async => [
        BackupModel(
            id: 'b1',
            name: 'PostgreSQL nightly',
            target: 'Main PostgreSQL',
            status: HealthState.healthy,
            createdAt: now.subtract(const Duration(hours: 8)),
            sizeMb: 1843,
            nextRun: now.add(const Duration(hours: 16))),
        BackupModel(
            id: 'b2',
            name: 'Jellyfin config',
            target: 'Media Stack',
            status: HealthState.healthy,
            createdAt: now.subtract(const Duration(days: 1)),
            sizeMb: 312,
            nextRun: now.add(const Duration(days: 1))),
        BackupModel(
            id: 'b3',
            name: 'Dokploy',
            target: 'Control plane',
            status: HealthState.warning,
            createdAt: now.subtract(const Duration(days: 3)),
            sizeMb: 94),
      ];
  @override
  Future<List<ScheduleModel>> schedules() async => [
        ScheduleModel(
            id: 'j1',
            name: 'Nightly cleanup',
            cron: '0 3 * * *',
            lastStatus: HealthState.healthy,
            lastRun: now.subtract(const Duration(hours: 10)),
            nextRun: now.add(const Duration(hours: 14))),
        ScheduleModel(
            id: 'j2',
            name: 'Refresh CRL',
            cron: '*/30 * * * *',
            lastStatus: HealthState.healthy,
            lastRun: now.subtract(const Duration(minutes: 12)),
            nextRun: now.add(const Duration(minutes: 18))),
        ScheduleModel(
            id: 'j3',
            name: 'DB maintenance',
            cron: '0 4 * * 0',
            lastStatus: HealthState.failed,
            lastRun: now.subtract(const Duration(days: 5)),
            nextRun: now.add(const Duration(days: 2))),
      ];
  @override
  Future<List<DomainModel>> domains() async => const [
        DomainModel(
            id: 'dm1',
            host: 'pki.example.com',
            target: 'PKI Dashboard',
            https: true,
            port: 8080),
        DomainModel(
            id: 'dm2',
            host: 'media.example.com',
            target: 'Media Stack / jellyfin',
            https: true,
            port: 8096),
        DomainModel(
            id: 'dm3',
            host: 'j2534.example.com',
            target: 'J2534 Server',
            https: true,
            port: 8080),
      ];
  @override
  Future<
      List<
          String>> logs(String serviceId, {int tail = 200}) async => List.generate(
      80,
      (i) =>
          '${now.subtract(Duration(seconds: 80 - i)).toIso8601String()}  ${i % 11 == 0 ? 'WARN' : 'INFO'}  ${i % 7 == 0 ? 'GET /api/health 200' : 'Application heartbeat ok'}');
  @override
  Future<List<ContainerInstance>> containers(ServiceModel service) async =>
      const [
        ContainerInstance(
          id: 'a1b2c3d4e5f6',
          name: 'app.1',
          state: 'running',
          runType: 'native',
        ),
        ContainerInstance(
          id: 'f6e5d4c3b2a1',
          name: 'app.2',
          state: 'shutdown',
          runType: 'swarm',
          node: 'worker-1',
          status: 'Shutdown 10 seconds ago',
        ),
      ];
  @override
  Stream<List<String>> watchContainerLogs(
    ServiceModel service,
    ContainerInstance container, {
    int tail = 200,
  }) =>
      Stream.value([
        '${now.toIso8601String()} INFO ${container.id} ready',
      ]);
  @override
  Future<List<String>> deploymentLogs(String deploymentId,
          {int tail = 500}) async =>
      List.generate(
        tail.clamp(1, 80),
        (i) => '${now.subtract(Duration(seconds: 80 - i)).toIso8601String()}  '
            '${i == 65 ? 'WARN health check pending' : i == 79 ? 'Deployment step completed' : 'Building layer ${i + 1}'}',
      );
  @override
  Future<void> start(ServiceModel service) async {}
  @override
  Future<void> stop(ServiceModel service) async {}
  @override
  Future<void> restart(ServiceModel service) async {}
  @override
  Future<void> redeploy(ServiceModel service) async {}
  @override
  Future<ServiceEnvironment> environment(ServiceModel service) async =>
      const ServiceEnvironment(
        env: 'APP_ENV=production\nAPI_URL=https://api.example.com',
      );
  @override
  Future<void> saveEnvironment(
    ServiceModel service,
    ServiceEnvironment environment,
  ) async {}
  @override
  Future<void> cancelDeployment(String deploymentId) async {}
  @override
  Future<void> setupMonitoring({String? serverId}) async {}
  @override
  Future<void> pruneDocker({String? serverId}) async {}

  @override
  Future<TraefikRequestPage> traefikRequests({int limit = 200}) async {
    final items = List.generate(
      18,
      (index) => TraefikRequestModel(
        timestamp: now.subtract(Duration(seconds: index * 19)),
        method: index % 5 == 0 ? 'POST' : 'GET',
        host: index.isEven ? 'api.example.com' : 'media.example.com',
        path: index % 4 == 0 ? '/api/deployments' : '/health',
        statusCode: const [200, 200, 201, 301, 404, 502][index % 6],
        durationMs: 18 + index * 7,
        clientHost: '10.0.0.${index + 2}',
        router: 'demo-router@file',
        service: 'demo-service@file',
        protocol: 'HTTP/2.0',
      ),
    );
    return TraefikRequestPage(
      enabled: true,
      items: items.take(limit).toList(),
      totalCount: items.length,
    );
  }

  @override
  Stream<ServerModel> watchControlPlaneMetrics() => const Stream.empty();

  @override
  Stream<ServiceModel> watchServiceMetrics(ServiceModel service) =>
      Stream.value(service);
}
