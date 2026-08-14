import 'dokploy_api.dart';
import 'repository.dart';
import '../domain/models.dart';

class RealDokployRepository implements DokployRepository {
  RealDokployRepository(this.api);
  final DokployApi api;

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
  Future<List<ProjectModel>> projects() async => _list(await api.projects())
      .whereType<Map>()
      .map((m) => ProjectModel(
          id: _s(m, ['projectId', 'id']),
          name: _s(m, ['name'], 'Unnamed'),
          description: _s(m, ['description'])))
      .toList();
  @override
  Future<List<DeploymentModel>> deployments() async =>
      _list(await api.deploymentsCentralized())
          .whereType<Map>()
          .map((m) => DeploymentModel(
              id: _s(m, ['deploymentId', 'id']),
              service: _s(
                  m,
                  ['title', 'applicationName', 'composeName', 'name'],
                  'Deployment'),
              status: _state(m['status']),
              createdAt:
                  DateTime.tryParse(_s(m, ['createdAt'])) ?? DateTime.now(),
              commit: _s(m, ['commit', 'commitSha']),
              branch: _s(m, ['branch'], 'main'),
              message: _s(m, ['description', 'message'])))
          .toList();
  @override
  Future<List<ServerModel>> servers() async => _list(await api.servers())
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
  @override
  Future<List<ServiceModel>> services() async {
    // project.one contains environment/application/compose relations on supported versions.
    final out = <ServiceModel>[];
    for (final p in await projects()) {
      final raw = await api.project(p.id);
      if (raw is! Map) continue;
      void add(dynamic xs, ServiceKind kind) {
        if (xs is List) {
          for (final x in xs.whereType<Map>()) {
            out.add(ServiceModel(
                id: _s(x, [
                  kind == ServiceKind.compose ? 'composeId' : 'applicationId',
                  'id'
                ]),
                name: _s(x, ['name', 'appName'], 'Service'),
                kind: kind,
                status: _state(x[kind == ServiceKind.compose
                    ? 'composeStatus'
                    : 'applicationStatus']),
                project: p.name,
                image: _s(x, ['dockerImage', 'image']),
                domain: '',
                appName: _s(x, ['appName', 'name'])));
          }
        }
      }

      final envs = raw['environments'];
      if (envs is List) {
        for (final e in envs.whereType<Map>()) {
          add(e['applications'], ServiceKind.application);
          add(e['compose'], ServiceKind.compose);
          add(e['composes'], ServiceKind.compose);
        }
      }
    }
    return out;
  }

  @override
  Future<DashboardSnapshot> dashboard() async {
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
          if (ss.any((x) => x.status == HealthState.failed))
            '${ss.where((x) => x.status == HealthState.failed).length} service(s) need attention'
        ]);
  }

  @override
  Future<List<String>> logs(String serviceId, {int tail = 200}) async {
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
  Future<void> start(ServiceModel s) => s.kind == ServiceKind.compose
      ? api.startCompose(s.id)
      : s.kind == ServiceKind.postgres
          ? api.startPostgres(s.id)
          : api.startApplication(s.id);
  @override
  Future<void> stop(ServiceModel s) => s.kind == ServiceKind.compose
      ? api.stopCompose(s.id)
      : s.kind == ServiceKind.postgres
          ? api.stopPostgres(s.id)
          : api.stopApplication(s.id);
  @override
  Future<void> redeploy(ServiceModel s) => s.kind == ServiceKind.compose
      ? api.deployCompose(s.id)
      : s.kind == ServiceKind.postgres
          ? api.deployPostgres(s.id)
          : api.redeployApplication(s.id);
  @override
  Future<void> cancelDeployment(String id) => api.cancelDeployment(id);
  @override
  Future<List<BackupModel>> backups() async => const [];
  @override
  Future<List<ScheduleModel>> schedules() async => const [];
  @override
  Future<List<DomainModel>> domains() async => const [];
}
