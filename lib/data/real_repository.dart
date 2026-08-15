import 'dart:convert';
import 'dart:math';

import 'dokploy_api.dart';
import 'repository.dart';
import '../domain/failures.dart';
import '../domain/models.dart';

class RealDokployRepository implements DokployRepository {
  RealDokployRepository(this.api);
  final DokployApi api;
  Future<CapabilitySet>? _capabilitiesRequest;
  Future<dynamic>? _projectsRequest;

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

  double _d(dynamic value) {
    if (value is num) return value.toDouble();
    final normalized = '$value'.trim().replaceAll(',', '.');
    final match = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(normalized);
    return match == null ? 0 : double.tryParse(match.group(0)!) ?? 0;
  }

  HealthState _state(dynamic v) {
    final s = '$v'.toLowerCase();
    if (s.contains('run') ||
        s.contains('done') ||
        s.contains('success') ||
        s == 'active') {
      return HealthState.healthy;
    }
    if (s.contains('deploy') || s.contains('queue') || s.contains('progress')) {
      return HealthState.deploying;
    }
    if (s.contains('fail') || s.contains('error')) return HealthState.failed;
    if (s.contains('stop') || s.contains('idle') || s == 'inactive') {
      return HealthState.stopped;
    }
    return HealthState.unknown;
  }

  @override
  Future<List<ProjectModel>> projects() async =>
      _list(await _projectHierarchy()).whereType<Map>().map((project) {
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

  Future<dynamic> _projectHierarchy() =>
      _projectsRequest ??= _loadProjectHierarchy();

  Future<dynamic> _loadProjectHierarchy() async {
    try {
      return await api.projects();
    } finally {
      _projectsRequest = null;
    }
  }

  @override
  Future<List<DeploymentModel>> deployments() async {
    if (!(await capabilities()).deployments) return const [];
    return _list(await api.deploymentsCentralized()).whereType<Map>().map((m) {
      final startedAt = DateTime.tryParse(_s(m, ['startedAt']));
      final finishedAt = DateTime.tryParse(_s(m, ['finishedAt']));
      final duration = startedAt == null
          ? 0
          : (finishedAt ?? DateTime.now()).difference(startedAt).inSeconds;
      return DeploymentModel(
        id: _s(m, ['deploymentId', 'id']),
        service: _deploymentService(m),
        serviceId: _deploymentServiceId(m),
        status: _state(m['status']),
        createdAt: DateTime.tryParse(_s(m, ['createdAt'])) ?? DateTime.now(),
        startedAt: startedAt,
        finishedAt: finishedAt,
        durationSeconds: duration < 0 ? 0 : duration,
        commit: _s(m, ['commit', 'commitSha']),
        branch: _s(m, ['branch'], 'main'),
        title: _s(m, ['title', 'trigger']),
        errorMessage: _s(m, ['errorMessage', 'error']),
        message: _s(m, ['description', 'message']),
      );
    }).toList();
  }

  @override
  Future<List<ServerModel>> servers() async {
    if (!(await capabilities()).servers) return const [];
    try {
      final caps = await capabilities();
      final rawServers = _list(await api.servers()).whereType<Map>().toList();
      final servers = await Future.wait(
        rawServers.map((server) => _serverWithMetrics(server, caps.metrics)),
      );
      if (caps.metrics) {
        final controlPlane = await _controlPlaneMetrics();
        if (controlPlane != null &&
            !servers.any((server) => server.host == controlPlane.host)) {
          servers.insert(0, controlPlane);
        }
      }
      return servers;
    } on DokployFailure catch (failure) {
      // Server inventory is an administrative capability. A token can be valid
      // for projects/deployments while Dokploy returns 401/403 for server.all.
      if (_isUnavailableCapability(failure)) return const [];
      rethrow;
    }
  }

  Future<ServerModel> _serverWithMetrics(Map raw, bool metricsAllowed) async {
    final host = _s(raw, ['ipAddress', 'host', 'hostname']);
    final base = ServerModel(
      id: _s(raw, ['serverId', 'id']),
      name: _s(raw, ['name'], 'Server'),
      host: host,
      status: _state(raw['serverStatus'] ?? raw['status']),
      cpu: 0,
      memory: 0,
      disk: 0,
      metricsAvailable: false,
      monitoringConfigured: false,
    );
    if (!metricsAllowed || host.isEmpty) return base;
    final config = _mapAt(_mapAt(raw, 'metricsConfig'), 'server');
    final token = _s(config, ['token']);
    final port = int.tryParse(_s(config, ['port'])) ?? 4500;
    if (token.isEmpty) return base;
    final url = Uri(scheme: 'http', host: host, port: port, path: '/metrics');
    return _loadServerMetrics(
      base.copyWith(monitoringConfigured: true),
      url.toString(),
      token,
    );
  }

  Future<ServerModel?> _controlPlaneMetrics() async {
    try {
      final raw = await api.metricsConfig();
      if (raw is! Map || raw.isEmpty) return null;
      final config = _mapAt(_mapAt(raw, 'metricsConfig'), 'server');
      final token = _s(config, ['token']);
      final host = _s(raw, ['serverIp'], 'localhost');
      final port = int.tryParse(_s(config, ['port'])) ?? 4500;
      final base = ServerModel(
        id: 'dokploy-control-plane',
        name: 'Dokploy host',
        host: host,
        status: HealthState.healthy,
        cpu: 0,
        memory: 0,
        disk: 0,
        metricsAvailable: false,
        monitoringConfigured: false,
      );
      if (token.isEmpty) return base;
      final url = Uri(scheme: 'http', host: host, port: port, path: '/metrics');
      return _loadServerMetrics(
        base.copyWith(monitoringConfigured: true),
        url.toString(),
        token,
      );
    } on DokployFailure {
      return null;
    }
  }

  Future<ServerModel> _loadServerMetrics(
    ServerModel base,
    String url,
    String token,
  ) async {
    try {
      final values = _metricList(
        await api.serverMetrics(url: url, token: token, dataPoints: 3),
      ).whereType<Map>();
      if (values.isEmpty) return base;
      final metric = values.last;
      return base.copyWith(
        cpu: _metricNumber(metric, ['cpu', 'CPU', 'cpuUsage']),
        memory: _metricNumber(
          metric,
          ['memUsed', 'memory', 'memoryUsed', 'memoryUsedPercentage'],
        ),
        disk: _metricNumber(
          metric,
          ['diskUsed', 'diskUsage', 'diskUsedPercentage'],
        ),
        metricsAvailable: true,
        monitoringConfigured: true,
        uptimeSeconds: _metricNumber(metric, ['uptime']).round(),
        networkInKbps: _metricNumber(metric, ['networkIn']),
        networkOutKbps: _metricNumber(metric, ['networkOut']),
        memoryUsedGb: _metricNumber(metric, ['memUsedGB', 'memoryUsedGB']),
        memoryTotalGb: _metricNumber(metric, ['memTotal', 'memoryTotal']),
        diskTotalGb: _metricNumber(metric, ['totalDisk', 'diskTotal']),
      );
    } on DokployFailure {
      return base;
    }
  }

  List<dynamic> _metricList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      for (final key in [
        'data',
        'metrics',
        'serverMetrics',
        'items',
        'result',
      ]) {
        final nested = data[key];
        if (nested is List) return nested;
        if (nested is Map) {
          final values = _metricList(nested);
          if (values.isNotEmpty) return values;
        }
      }
      if (data.keys.any((key) =>
          const ['cpu', 'CPU', 'memUsed', 'diskUsed'].contains('$key'))) {
        return [data];
      }
    }
    return const [];
  }

  double _metricNumber(Map metric, List<String> keys) {
    for (final key in keys) {
      if (metric[key] != null) return _d(metric[key]);
    }
    return 0;
  }

  @override
  Future<void> setupMonitoring({String? serverId}) async {
    final random = Random.secure();
    final token = base64UrlEncode(
      List<int>.generate(48, (_) => random.nextInt(256)),
    ).replaceAll('=', '');
    final config = <String, dynamic>{
      'server': {
        'refreshRate': 60,
        'port': 4500,
        'token': token,
        'urlCallback': api.monitoringCallbackUrl,
        'retentionDays': 2,
        'cronJob': '0 0 * * *',
        'thresholds': {'cpu': 0, 'memory': 0},
      },
      'containers': {
        'refreshRate': 60,
        'services': {
          'include': <String>[],
          'exclude': <String>[],
        },
      },
    };
    if (serverId == null) {
      await api.setupControlPlaneMonitoring(config);
    } else {
      await api.setupServerMonitoring(serverId, config);
    }
  }

  @override
  Future<void> pruneDocker({String? serverId}) =>
      api.cleanDockerPrune(serverId: serverId);

  Map _mapAt(Map parent, String key) {
    final value = parent[key];
    return value is Map ? value : const {};
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
    for (final project in _list(await _projectHierarchy()).whereType<Map>()) {
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
                serverId: _s(service, ['serverId']),
                metricsAvailable: false,
              ),
            );
          }
        }
      }
    }
    return services;
  }

  @override
  Future<ServiceModel> serviceDetails(ServiceModel service) async {
    try {
      final raw = switch (service.kind) {
        ServiceKind.application => await api.application(service.id),
        ServiceKind.compose => await api.compose(service.id),
        _ => null,
      };
      if (raw is! Map) return service;

      final domains = _listAt(raw, 'domains');
      final detailed = service.copyWith(
        name: _s(raw, ['name'], service.name),
        image: _s(raw, ['dockerImage', 'image'], service.image),
        domain: domains.isEmpty
            ? service.domain
            : _s(domains.first, ['host'], service.domain),
        appName: _s(raw, ['appName'], service.appName),
        serverId: _s(raw, ['serverId'], service.serverId),
      );
      if (service.kind != ServiceKind.application ||
          detailed.appName.isEmpty ||
          !(await capabilities()).metrics) {
        return detailed;
      }
      return _applicationWithMonitoring(detailed);
    } on DokployFailure catch (failure) {
      if (_isUnavailableCapability(failure)) return service;
      rethrow;
    }
  }

  Future<ServiceModel> _applicationWithMonitoring(ServiceModel service) async {
    try {
      final raw = await api.applicationMonitoring(service.appName);
      if (raw is! Map) return service;
      final cpu = _latestMonitoringValue(raw, 'cpu');
      final memory = _latestMonitoringValue(raw, 'memory');
      final network = _latestMonitoringValue(raw, 'network');
      final timestamps = [cpu, memory, network]
          .map((entry) => DateTime.tryParse(_s(entry, ['time'])))
          .whereType<DateTime>()
          .toList();
      final memoryValue = _mapAt(memory, 'value');
      final networkValue = _mapAt(network, 'value');
      final hasMetrics =
          cpu.isNotEmpty || memory.isNotEmpty || network.isNotEmpty;
      return service.copyWith(
        cpu: _d(cpu['value']),
        memoryMb: _toMegabytes(memoryValue['used']),
        networkReceivedMb: _toMegabytes(networkValue['inputMb']),
        networkSentMb: _toMegabytes(networkValue['outputMb']),
        metricsAvailable: hasMetrics,
        metricsUpdatedAt: timestamps.isEmpty
            ? null
            : timestamps.reduce((a, b) => a.isAfter(b) ? a : b),
      );
    } on DokployFailure catch (failure) {
      if (_isUnavailableCapability(failure)) return service;
      rethrow;
    }
  }

  Map _latestMonitoringValue(Map raw, String key) {
    final values = raw[key];
    return values is List && values.isNotEmpty && values.last is Map
        ? values.last as Map
        : const {};
  }

  double _toMegabytes(dynamic value) {
    final text = '$value'.trim();
    final amount = _d(text);
    final unit = text.replaceAll(RegExp(r'[0-9.,\s-]'), '').toLowerCase();
    return switch (unit) {
      'b' => amount / (1024 * 1024),
      'kb' || 'kib' => amount / 1024,
      'gb' || 'gib' => amount * 1024,
      'tb' || 'tib' => amount * 1024 * 1024,
      _ => amount,
    };
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

  String _deploymentServiceId(Map deployment) {
    for (final key in ['applicationId', 'composeId']) {
      final value = _s(deployment, [key]);
      if (value.isNotEmpty) return value;
    }
    for (final entry in const {
      'application': 'applicationId',
      'compose': 'composeId',
    }.entries) {
      final service = deployment[entry.key];
      if (service is Map) {
        final value = _s(service, [entry.value, 'id']);
        if (value.isNotEmpty) return value;
      }
    }
    return '';
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
  Future<List<String>> deploymentLogs(String deploymentId,
      {int tail = 500}) async {
    if (!(await capabilities()).deployments) {
      throw _unsupported('deployment.readLogs');
    }
    final data = await api.deploymentLogs(deploymentId, tail: tail);
    if (data is String) return data.isEmpty ? const [] : data.split('\n');
    if (data is List) return data.map((entry) => '$entry').toList();
    if (data is Map) {
      final logs = data['logs'] ?? data['data'];
      if (logs is String) return logs.isEmpty ? const [] : logs.split('\n');
      if (logs is List) return logs.map((entry) => '$entry').toList();
    }
    return data == null ? const [] : ['$data'];
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
