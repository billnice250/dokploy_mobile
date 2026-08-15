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
        name: 'PKI Dashboard',
        kind: ServiceKind.application,
        status: HealthState.healthy,
        project: 'Production',
        image: 'registry/pki-dashboard:latest',
        domain: 'pki.example.com',
        cpu: 4.2,
        memoryMb: 287,
        networkReceivedMb: 1.4,
        networkSentMb: .3,
        appName: 'pki-dashboard'),
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
        image: 'registry/j2534:1.2.29',
        domain: 'j2534.example.com',
        cpu: 7.1,
        memoryMb: 410,
        appName: 'j2534-server'),
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
            service: 'PKI Dashboard',
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
  Future<void> redeploy(ServiceModel service) async {}
  @override
  Future<void> cancelDeployment(String deploymentId) async {}
  @override
  Future<void> setupMonitoring({String? serverId}) async {}
  @override
  Future<void> pruneDocker({String? serverId}) async {}
}
