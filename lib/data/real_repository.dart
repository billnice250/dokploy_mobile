import 'dokploy_api.dart';
import 'repository.dart';
import '../domain/failures.dart';
import '../domain/models.dart';

class RealDokployRepository implements DokployRepository {
  RealDokployRepository(this.api);
  final DokployApi api;
  Future<CapabilitySet>? _capabilitiesRequest;

  @override
  Future<CapabilitySet> capabilities() =>
      _capabilitiesRequest ??= _loadCapabilities();

  Future<CapabilitySet> _loadCapabilities() async {
    try {
      final raw = await api.permissions();
      if (raw is! Map) return CapabilitySet.core;
      bool allowed(String resource, String action) {
        final permissions = raw[resource];
        return permissions is Map && permissions[action] == true;
      }

      final serviceRead = allowed('service', 'read');
      return CapabilitySet(
        logs: serviceRead && allowed('logs', 'read'),
        deployments: allowed('deployment', 'read'),
        cancelDeployments: allowed('deployment', 'cancel'),
        lifecycle: allowed('deployment', 'create'),
        compose: serviceRead,
        metrics: allowed('monitoring', 'read'),
        servers: allowed('server', 'read'),
        // These adapters are not implemented yet. A server permission alone
        // must not make an unfinished control appear active.
        backups: false,
        schedules: false,
        domains: false,
        databases: serviceRead,
      );
    } on DokployFailure {
      // Older/changed Dokploy versions may not expose this endpoint to API
      // keys. Keep only project-derived, read-only capabilities in that case.
      return CapabilitySet.core;
    }
  }

  List<dynamic> _list(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      for (final key in [
        'data',
        'items',
        'projects',
        'deployments',
        'servers'
      ]) {
        final value = data[key];
        if (value is List) return value;
      }
    }
    return const [];
  }

  String _s(Map m, List<String> keys, [String fallback = '']) {
    for (final k in keys) {
      if (m[k] != null) return '${m[k]}';
    }
    return fallback;
  }

  double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
  HealthState _state(dynamic v) {
    final s = '$v'.toLowerCase();
    if (s.contains('run') || s.contains('done') || s.contains('success')) {
      return HealthState.healthy;
    }
    if (s.contains('deploy') || s.contains('queue') || s.contains('progress')) {
      return HealthState.deploying;
    }
    if (s.contains('fail') || s.contains('error')) return HealthState.failed;
    if (s.contains('stop') || s.contains('idle')) return HealthState.stopped;
    return HealthState.unknown;
  }

  @override
  Future<List<ProjectModel>> projects() async =>
      _list(await api.projects()).whereType<Map>().map((project) {
        final environments = _listAt(project, 'environments');
        final serviceCount = environments.fold<int>(
          0,
          (count, environment) =>
              count +
              _serviceCollectionKeys.fold<int>(
                0,
                (total, key) => total + _listAt(environment, key).length,
              ),
        );
        return ProjectModel(
          id: _s(project, ['projectId', 'id']),
          name: _s(project, ['name'], 'Unnamed'),
          description: _s(project, ['description']),
          environmentCount: environments.length,
          serviceCount: serviceCount,
        );
      }).toList();
  @override
  Future<List<DeploymentModel>> deployments() async {
    if (!(await capabilities()).deployments) return const [];
    return _list(await api.deploymentsCentralized())
        .whereType<Map>()
        .map((m) => DeploymentModel(
            id: _s(m, ['deploymentId', 'id']),
            service: _deploymentService(m),
            status: _state(m['status']),
            createdAt:
                DateTime.tryParse(_s(m, ['createdAt'])) ?? DateTime.now(),
            commit: _s(m, ['commit', 'commitSha']),
            branch: _s(m, ['branch'], 'main'),
            message: _s(m, ['description', 'message'])))
        .toList();
  }

  @override
  Future<List<ServerModel>> servers() async {
    if (!(await capabilities()).servers) return const [];
    try {
      return _list(await api.servers())
          .whereType<Map>()
          .map((m) => ServerModel(
              id: _s(m, ['serverId', 'id']),
              name: _s(m, ['name'], 'Server'),
              host: _s(m, ['ipAddress', 'host', 'hostname']),
              status: _state(m['status']),
              cpu: _d(m['cpu']),
              memory: _d(m['memory']),
              disk: _d(m['disk'])))
          .toList();
    } on DokployFailure catch (failure) {
      // Server inventory is an administrative capability. A token can be valid
      // for projects/deployments while Dokploy returns 401/403 for server.all.
      if (_isUnavailableCapability(failure)) return const [];
      rethrow;
    }
  }

  bool _isUnavailableCapability(DokployFailure failure) =>
      failure.kind == DokployFailureKind.unauthorized ||
      failure.kind == DokployFailureKind.forbidden ||
      failure.kind == DokployFailureKind.notFound ||
      failure.kind == DokployFailureKind.unsupportedFeature;
  @override
  Future<List<ServiceModel>> services() async {
    // project.all already contains the complete project → environment →
    // service hierarchy in Dokploy v0.29.14. Mapping it directly avoids extra
    // project.one requests and keeps this read path compatible with API keys.
    final services = <ServiceModel>[];
    for (final project in _list(await api.projects()).whereType<Map>()) {
      final projectName = _s(project, ['name'], 'Unnamed');
      for (final environment in _listAt(project, 'environments')) {
        for (final entry in _serviceKinds.entries) {
          for (final service in _listAt(environment, entry.key)) {
            final kind = entry.value;
            services.add(
              ServiceModel(
                id: _s(service, [_idKey(kind), 'id']),
                name: _s(service, ['name', 'appName'], 'Service'),
                kind: kind,
                status: _state(
                  service[kind == ServiceKind.compose
                      ? 'composeStatus'
                      : 'applicationStatus'],
                ),
                project: projectName,
                image: _s(service, ['dockerImage', 'image']),
                domain: '',
                appName: _s(service, ['appName', 'name']),
              ),
            );
          }
        }
      }
    }
    return services;
  }

  static const _serviceKinds = <String, ServiceKind>{
    'applications': ServiceKind.application,
    'compose': ServiceKind.compose,
    'composes': ServiceKind.compose,
    'postgres': ServiceKind.postgres,
    'mysql': ServiceKind.mysql,
    'mariadb': ServiceKind.mariadb,
    'mongo': ServiceKind.mongo,
    'redis': ServiceKind.redis,
  };

  static const _serviceCollectionKeys = <String>[
    'applications',
    'compose',
    'postgres',
    'mysql',
    'mariadb',
    'mongo',
    'redis',
    'libsql',
  ];

  List<Map> _listAt(Map parent, String key) {
    final value = parent[key];
    return value is List ? value.whereType<Map>().toList() : const [];
  }

  String _idKey(ServiceKind kind) => switch (kind) {
        ServiceKind.application => 'applicationId',
        ServiceKind.compose => 'composeId',
        ServiceKind.postgres => 'postgresId',
        ServiceKind.mysql => 'mysqlId',
        ServiceKind.mariadb => 'mariadbId',
        ServiceKind.mongo => 'mongoId',
        ServiceKind.redis => 'redisId',
      };

  String _deploymentService(Map deployment) {
    for (final key in ['application', 'compose']) {
      final service = deployment[key];
      if (service is Map) {
        final name = _s(service, ['name', 'appName']);
        if (name.isNotEmpty) return name;
      }
    }
    return _s(
      deployment,
      ['applicationName', 'composeName', 'name', 'title'],
      'Deployment',
    );
  }

  @override
  Future<DashboardSnapshot> dashboard() async {
    final caps = await capabilities();
    final ss = await services();
    final ds = await deployments();
    final sv = await servers();
    final ps = await projects();
    return DashboardSnapshot(
        running: ss.where((x) => x.status == HealthState.healthy).length,
        stopped: ss.where((x) => x.status == HealthState.stopped).length,
        failed: ss.where((x) => x.status == HealthState.failed).length,
        projects: ps,
        deployments: ds.take(5).toList(),
        servers: sv,
        attention: [
          if (!caps.servers)
            'Server inventory is unavailable for this API token',
          if (ss.any((x) => x.status == HealthState.failed))
            '${ss.where((x) => x.status == HealthState.failed).length} service(s) need attention'
        ]);
  }

  @override
  Future<List<String>> logs(String serviceId, {int tail = 200}) async {
    if (!(await capabilities()).logs) {
      throw _unsupported('application.readLogs');
    }
    final data = await api.applicationLogs(serviceId, tail: tail);
    if (data is String) return data.split('\n');
    if (data is List) return data.map((e) => '$e').toList();
    if (data is Map) {
      final v = data['logs'] ?? data['data'];
      if (v is String) return v.split('\n');
      if (v is List) return v.map((e) => '$e').toList();
    }
    return ['$data'];
  }

  @override
  Future<void> start(ServiceModel s) async {
    if (!(await capabilities()).lifecycle) throw _unsupported('start');
    return s.kind == ServiceKind.compose
        ? api.startCompose(s.id)
        : s.kind == ServiceKind.postgres
            ? api.startPostgres(s.id)
            : api.startApplication(s.id);
  }

  @override
  Future<void> stop(ServiceModel s) async {
    if (!(await capabilities()).lifecycle) throw _unsupported('stop');
    return s.kind == ServiceKind.compose
        ? api.stopCompose(s.id)
        : s.kind == ServiceKind.postgres
            ? api.stopPostgres(s.id)
            : api.stopApplication(s.id);
  }

  @override
  Future<void> redeploy(ServiceModel s) async {
    if (!(await capabilities()).lifecycle) throw _unsupported('redeploy');
    return s.kind == ServiceKind.compose
        ? api.deployCompose(s.id)
        : s.kind == ServiceKind.postgres
            ? api.deployPostgres(s.id)
            : api.redeployApplication(s.id);
  }

  @override
  Future<void> cancelDeployment(String id) async {
    if (!(await capabilities()).cancelDeployments) {
      throw _unsupported('deployment.killProcess');
    }
    return api.cancelDeployment(id);
  }

  DokployFailure _unsupported(String operation) => DokployFailure(
        kind: DokployFailureKind.unsupportedFeature,
        operation: operation,
        message: 'This API token does not grant access to $operation.',
      );
  @override
  Future<List<BackupModel>> backups() async => const [];
  @override
  Future<List<ScheduleModel>> schedules() async => const [];
  @override
  Future<List<DomainModel>> domains() async => const [];
}
