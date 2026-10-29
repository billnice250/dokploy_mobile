import '../domain/models.dart';

abstract interface class DokployRepository {
  Future<CapabilitySet> capabilities();
  Future<DashboardSnapshot> dashboard();
  Future<List<ProjectModel>> projects();
  Future<List<ServiceModel>> services();
  Future<ServiceModel> serviceDetails(ServiceModel service);
  Future<String> composePreview(ServiceModel service);
  Future<List<DeploymentModel>> deployments();
  Future<List<ServerModel>> servers();
  Future<List<BackupModel>> backups();
  Future<List<ScheduleModel>> schedules();
  Future<List<DomainModel>> domains();
  Future<TraefikRequestPage> traefikRequests({int limit = 200});
  Stream<ServerModel> watchControlPlaneMetrics();
  Stream<ServiceModel> watchServiceMetrics(ServiceModel service);
  Future<List<ContainerInstance>> containers(ServiceModel service);
  Stream<List<String>> watchContainerLogs(
    ServiceModel service,
    ContainerInstance container, {
    int tail = 200,
  });
  Future<List<String>> logs(String serviceId, {int tail = 200});
  Future<List<String>> deploymentLogs(String deploymentId, {int tail = 500});
  Future<void> start(ServiceModel service);
  Future<void> stop(ServiceModel service);
  Future<void> restart(ServiceModel service);
  Future<void> redeploy(ServiceModel service);
  Future<ServiceEnvironment> environment(ServiceModel service);
  Future<void> saveEnvironment(
    ServiceModel service,
    ServiceEnvironment environment,
  );
  Future<void> cancelDeployment(String deploymentId);
  Future<void> setupMonitoring({String? serverId});
  Future<void> pruneDocker({String? serverId});
}
