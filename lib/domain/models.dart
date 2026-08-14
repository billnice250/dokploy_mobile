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
  const CapabilitySet(
      {this.logs = true,
      this.deployments = true,
      this.compose = true,
      this.metrics = true,
      this.backups = true,
      this.schedules = true,
      this.domains = true,
      this.terminal = false,
      this.databases = true});
  final bool logs,
      deployments,
      compose,
      metrics,
      backups,
      schedules,
      domains,
      terminal,
      databases;
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
      this.networkDownMbps = 0,
      this.networkUpMbps = 0,
      this.appName = ''});
  final String id, name, project, image, domain, appName;
  final ServiceKind kind;
  final HealthState status;
  final double cpu, memoryMb, networkDownMbps, networkUpMbps;
}

class DeploymentModel {
  const DeploymentModel(
      {required this.id,
      required this.service,
      required this.status,
      required this.createdAt,
      this.commit = '',
      this.branch = 'main',
      this.message = '',
      this.durationSeconds = 0});
  final String id, service, commit, branch, message;
  final HealthState status;
  final DateTime createdAt;
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
      required this.disk});
  final String id, name, host;
  final HealthState status;
  final double cpu, memory, disk;
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
