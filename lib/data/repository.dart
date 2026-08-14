import '../domain/models.dart';

abstract interface class DokployRepository {
  Future<CapabilitySet> capabilities();
  Future<DashboardSnapshot> dashboard();
  Future<List<ProjectModel>> projects();
  Future<List<ServiceModel>> services();
  Future<List<DeploymentModel>> deployments();
  Future<List<ServerModel>> servers();
  Future<List<BackupModel>> backups();
  Future<List<ScheduleModel>> schedules();
  Future<List<DomainModel>> domains();
  Future<List<String>> logs(String serviceId, {int tail = 200});
  Future<void> start(ServiceModel service);
  Future<void> stop(ServiceModel service);
  Future<void> redeploy(ServiceModel service);
  Future<void> cancelDeployment(String deploymentId);
}
