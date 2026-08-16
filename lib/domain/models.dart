enum ServiceKind {
  application,
  compose,
  postgres,
  mysql,
  mariadb,
  mongo,
  redis
}

enum HealthState { healthy, warning, failed, stopped, deploying, unknown }

class ServiceEnvironment {
  const ServiceEnvironment({
    this.env = '',
    this.buildArgs,
    this.buildSecrets,
    this.createEnvFile = false,
  });

  final String env;
  final String? buildArgs;
  final String? buildSecrets;
  final bool createEnvFile;

  ServiceEnvironment copyWith({String? env, bool? createEnvFile}) =>
      ServiceEnvironment(
        env: env ?? this.env,
        buildArgs: buildArgs,
        buildSecrets: buildSecrets,
        createEnvFile: createEnvFile ?? this.createEnvFile,
      );
}

class DokployInstance {
  const DokployInstance(
      {required this.id,
      required this.name,
      required this.baseUrl,
      this.version = 'unknown',
      this.demo = false});
  final String id;
  final String name;
  final String baseUrl;
  final String version;
  final bool demo;
}

class CapabilitySet {
  const CapabilitySet({
    this.logs = false,
    this.deployments = false,
    this.cancelDeployments = false,
    this.lifecycle = false,
    this.compose = false,
    this.metrics = false,
    this.servers = false,
    this.backups = false,
    this.schedules = false,
    this.domains = false,
    this.terminal = false,
    this.databases = false,
    this.traefikRequests = false,
  });

  static const core = CapabilitySet(compose: true, databases: true);

  static const demo = CapabilitySet(
    logs: true,
    deployments: true,
    cancelDeployments: true,
    lifecycle: true,
    compose: true,
    metrics: true,
    servers: true,
    backups: true,
    schedules: true,
    domains: true,
    databases: true,
    traefikRequests: true,
  );

  final bool logs,
      deployments,
      cancelDeployments,
      lifecycle,
      compose,
      metrics,
      servers,
      backups,
      schedules,
      domains,
      terminal,
      databases,
      traefikRequests;
}

class ProjectModel {
  const ProjectModel(
      {required this.id,
      required this.name,
      this.description = '',
      this.environmentCount = 0,
      this.serviceCount = 0});
  final String id, name, description;
  final int environmentCount, serviceCount;
}

class ServiceModel {
  const ServiceModel(
      {required this.id,
      required this.name,
      required this.kind,
      required this.status,
      this.project = 'Production',
      this.image = '',
      this.domain = '',
      this.cpu = 0,
      this.memoryMb = 0,
      this.networkReceivedMb = 0,
      this.networkSentMb = 0,
      this.appName = '',
      this.serverId = '',
      this.metricsAvailable = true,
      this.metricsUpdatedAt});
  final String id, name, project, image, domain, appName, serverId;
  final ServiceKind kind;
  final HealthState status;
  final double cpu, memoryMb, networkReceivedMb, networkSentMb;
  final bool metricsAvailable;
  final DateTime? metricsUpdatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ServiceModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  ServiceModel copyWith({
    String? name,
    HealthState? status,
    String? image,
    String? domain,
    String? appName,
    String? serverId,
    double? cpu,
    double? memoryMb,
    double? networkReceivedMb,
    double? networkSentMb,
    bool? metricsAvailable,
    DateTime? metricsUpdatedAt,
  }) =>
      ServiceModel(
        id: id,
        name: name ?? this.name,
        kind: kind,
        status: status ?? this.status,
        project: project,
        image: image ?? this.image,
        domain: domain ?? this.domain,
        appName: appName ?? this.appName,
        serverId: serverId ?? this.serverId,
        cpu: cpu ?? this.cpu,
        memoryMb: memoryMb ?? this.memoryMb,
        networkReceivedMb: networkReceivedMb ?? this.networkReceivedMb,
        networkSentMb: networkSentMb ?? this.networkSentMb,
        metricsAvailable: metricsAvailable ?? this.metricsAvailable,
        metricsUpdatedAt: metricsUpdatedAt ?? this.metricsUpdatedAt,
      );
}

class DeploymentModel {
  const DeploymentModel(
      {required this.id,
      required this.service,
      required this.status,
      required this.createdAt,
      this.serviceId = '',
      this.commit = '',
      this.branch = 'main',
      this.message = '',
      this.title = '',
      this.errorMessage = '',
      this.startedAt,
      this.finishedAt,
      this.durationSeconds = 0});
  final String id,
      service,
      serviceId,
      commit,
      branch,
      message,
      title,
      errorMessage;
  final HealthState status;
  final DateTime createdAt;
  final DateTime? startedAt, finishedAt;
  final int durationSeconds;
}

class ServerModel {
  const ServerModel(
      {required this.id,
      required this.name,
      required this.host,
      required this.status,
      required this.cpu,
      required this.memory,
      required this.disk,
      this.metricsAvailable = true,
      this.uptimeSeconds = 0,
      this.networkInKbps = 0,
      this.networkOutKbps = 0,
      this.memoryUsedGb = 0,
      this.memoryTotalGb = 0,
      this.diskTotalGb = 0,
      this.monitoringConfigured = true});
  final String id, name, host;
  final HealthState status;
  final double cpu,
      memory,
      disk,
      networkInKbps,
      networkOutKbps,
      memoryUsedGb,
      memoryTotalGb,
      diskTotalGb;
  final int uptimeSeconds;
  final bool metricsAvailable, monitoringConfigured;

  double get diskUsedGb => diskTotalGb * disk / 100;
  double get diskFreeGb => diskTotalGb - diskUsedGb;

  ServerModel copyWith({
    double? cpu,
    double? memory,
    double? disk,
    bool? metricsAvailable,
    bool? monitoringConfigured,
    int? uptimeSeconds,
    double? networkInKbps,
    double? networkOutKbps,
    double? memoryUsedGb,
    double? memoryTotalGb,
    double? diskTotalGb,
  }) =>
      ServerModel(
        id: id,
        name: name,
        host: host,
        status: status,
        cpu: cpu ?? this.cpu,
        memory: memory ?? this.memory,
        disk: disk ?? this.disk,
        metricsAvailable: metricsAvailable ?? this.metricsAvailable,
        monitoringConfigured: monitoringConfigured ?? this.monitoringConfigured,
        uptimeSeconds: uptimeSeconds ?? this.uptimeSeconds,
        networkInKbps: networkInKbps ?? this.networkInKbps,
        networkOutKbps: networkOutKbps ?? this.networkOutKbps,
        memoryUsedGb: memoryUsedGb ?? this.memoryUsedGb,
        memoryTotalGb: memoryTotalGb ?? this.memoryTotalGb,
        diskTotalGb: diskTotalGb ?? this.diskTotalGb,
      );
}

class BackupModel {
  const BackupModel(
      {required this.id,
      required this.name,
      required this.target,
      required this.status,
      required this.createdAt,
      required this.sizeMb,
      this.nextRun});
  final String id, name, target;
  final HealthState status;
  final DateTime createdAt;
  final double sizeMb;
  final DateTime? nextRun;
}

class ScheduleModel {
  const ScheduleModel(
      {required this.id,
      required this.name,
      required this.cron,
      required this.lastStatus,
      this.lastRun,
      this.nextRun});
  final String id, name, cron;
  final HealthState lastStatus;
  final DateTime? lastRun, nextRun;
}

class DomainModel {
  const DomainModel(
      {required this.id,
      required this.host,
      required this.target,
      required this.https,
      required this.port});
  final String id, host, target;
  final bool https;
  final int port;
}

class TraefikRequestModel {
  const TraefikRequestModel({
    required this.timestamp,
    required this.method,
    required this.host,
    required this.path,
    required this.statusCode,
    this.durationMs = 0,
    this.clientHost = '',
    this.router = '',
    this.service = '',
    this.protocol = '',
  });

  final DateTime timestamp;
  final String method, host, path, clientHost, router, service, protocol;
  final int statusCode;
  final double durationMs;
}

class TraefikRequestPage {
  const TraefikRequestPage({
    required this.enabled,
    required this.items,
    required this.totalCount,
  });

  final bool enabled;
  final List<TraefikRequestModel> items;
  final int totalCount;
}

class DashboardSnapshot {
  const DashboardSnapshot(
      {required this.running,
      required this.stopped,
      required this.failed,
      required this.projects,
      required this.deployments,
      required this.servers,
      required this.attention});
  final int running, stopped, failed;
  final List<ProjectModel> projects;
  final List<DeploymentModel> deployments;
  final List<ServerModel> servers;
  final List<String> attention;
}
