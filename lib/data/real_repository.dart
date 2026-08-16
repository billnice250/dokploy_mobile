import 'dart:async';
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
  dynamic _projectsCache;
  DateTime? _projectsCachedAt;
  Future<List<DeploymentModel>>? _deploymentsRequest;

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
        traefikRequests: serviceRead,
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
    final text = '$value'.trim().replaceAll(',', '.');
    var token = '';
    var hasDigit = false;
    var hasDecimal = false;
    for (final codeUnit in text.codeUnits) {
      final isDigit = codeUnit >= 48 && codeUnit <= 57;
      if (isDigit) {
        token += String.fromCharCode(codeUnit);
        hasDigit = true;
        continue;
      }
      if (codeUnit == 45 && token.isEmpty) {
        token = '-';
        continue;
      }
      if (codeUnit == 46 && !hasDecimal) {
        token = switch (token) {
          '' => '0.',
          '-' => '-0.',
          _ => '$token.',
        };
        hasDecimal = true;
        continue;
      }
      if (hasDigit) break;
      token = '';
      hasDecimal = false;
    }
    return double.tryParse(token) ?? 0;
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

  HealthState _deploymentState(dynamic value) {
    final status = '$value'.toLowerCase();
    if (status.contains('run') ||
        status.contains('deploy') ||
        status.contains('queue') ||
        status.contains('progress') ||
        status.contains('pending')) {
      return HealthState.deploying;
    }
    if (status.contains('done') ||
        status.contains('success') ||
        status.contains('complete')) {
      return HealthState.healthy;
    }
    if (status.contains('fail') || status.contains('error')) {
      return HealthState.failed;
    }
    if (status.contains('cancel') || status.contains('stop')) {
      return HealthState.stopped;
    }
    return HealthState.unknown;
  }

  HealthState _serviceState(dynamic value) {
    final status = '$value'.toLowerCase();
    // applicationStatus/composeStatus describe the deployment operation, not
    // Docker health. Dokploy uses `running` while that operation is active.
    if (status.contains('run') ||
        status.contains('deploy') ||
        status.contains('queue') ||
        status.contains('progress') ||
        status.contains('pending')) {
      return HealthState.deploying;
    }
    if (status.contains('done') ||
        status.contains('success') ||
        status.contains('complete') ||
        status == 'active' ||
        status.contains('healthy')) {
      return HealthState.healthy;
    }
    if (status.contains('fail') || status.contains('error')) {
      return HealthState.failed;
    }
    if (status.contains('stop') ||
        status.contains('idle') ||
        status == 'inactive') {
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

  Future<dynamic> _projectHierarchy() {
    final cachedAt = _projectsCachedAt;
    if (_projectsCache != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < const Duration(seconds: 5)) {
      return Future.value(_projectsCache);
    }
    return _projectsRequest ??= _loadProjectHierarchy();
  }

  Future<dynamic> _loadProjectHierarchy() async {
    try {
      final value = await api.projects();
      _projectsCache = value;
      _projectsCachedAt = DateTime.now();
      return value;
    } finally {
      _projectsRequest = null;
    }
  }

  @override
  Future<List<DeploymentModel>> deployments() =>
      _deploymentsRequest ??= _loadDeployments();

  Future<List<DeploymentModel>> _loadDeployments() async {
    try {
      if (!(await capabilities()).deployments) return const [];
      return _list(await api.deploymentsCentralized())
          .whereType<Map>()
          .map((m) {
        final startedAt = DateTime.tryParse(_s(m, ['startedAt']));
        final finishedAt = DateTime.tryParse(_s(m, ['finishedAt']));
        final duration = startedAt == null
            ? 0
            : (finishedAt ?? DateTime.now()).difference(startedAt).inSeconds;
        return DeploymentModel(
          id: _s(m, ['deploymentId', 'id']),
          service: _deploymentService(m),
          serviceId: _deploymentServiceId(m),
          status: _deploymentState(m['status']),
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
    } finally {
      _deploymentsRequest = null;
    }
  }

  @override
  Future<List<ServerModel>> servers() async {
    if (!(await capabilities()).servers) return const [];
    try {
      final rawServers = _list(await api.servers()).whereType<Map>().toList();
      final servers = await Future.wait(
        rawServers.map((server) => _serverWithMetrics(server)),
      );
      final controlPlane = await _controlPlaneMetrics();
      if (controlPlane != null &&
          !servers.any((server) => server.host == controlPlane.host)) {
        servers.insert(0, controlPlane);
      }
      return servers;
    } on DokployFailure catch (failure) {
      // Server inventory is an administrative capability. A token can be valid
      // for projects/deployments while Dokploy returns 401/403 for server.all.
      if (_isUnavailableCapability(failure)) return const [];
      rethrow;
    }
  }

  Future<ServerModel> _serverWithMetrics(Map raw) async {
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
    if (host.isEmpty) return base;
    final config = _mapAt(_mapAt(raw, 'metricsConfig'), 'server');
    final token = _s(config, ['token']);
    final port = int.tryParse(_s(config, ['port'])) ?? 4500;
    if (token.isNotEmpty) {
      final url = Uri(scheme: 'http', host: host, port: port, path: '/metrics');
      final monitored = await _loadServerMetrics(
        base.copyWith(monitoringConfigured: true),
        url.toString(),
        token,
      );
      if (monitored.metricsAvailable) return monitored;
    }
    return _serverHealthFallback(base, serverId: base.id);
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
      final free = await _freeHostMetrics(base);
      if (free.metricsAvailable) return free;
      if (token.isNotEmpty && raw['enabledFeatures'] != false) {
        final url =
            Uri(scheme: 'http', host: host, port: port, path: '/metrics');
        final monitored = await _loadServerMetrics(
          base.copyWith(monitoringConfigured: true),
          url.toString(),
          token,
        );
        if (monitored.metricsAvailable) return monitored;
      }
      return _serverHealthFallback(base);
    } on DokployFailure {
      return null;
    }
  }

  Future<ServerModel> _serverHealthFallback(
    ServerModel base, {
    String? serverId,
  }) async {
    try {
      final raw = await api
          .serverHealth(serverId: serverId)
          .timeout(const Duration(seconds: 6));
      if (raw is! Map) return base;
      final resources = _mapAt(raw, 'resources');
      final disk = _mapAt(raw, 'disk');
      final memoryTotal = _d(resources['memTotalBytes']);
      final memoryUsed = _d(resources['memUsedBytes']);
      final diskTotal = _d(disk['totalBytes']);
      final diskUsed = _d(disk['usedBytes']);
      if (memoryTotal <= 0 && diskTotal <= 0) return base;
      return base.copyWith(
        memory: memoryTotal <= 0 ? 0 : memoryUsed / memoryTotal * 100,
        disk: diskTotal <= 0 ? 0 : diskUsed / diskTotal * 100,
        memoryUsedGb: memoryUsed / (1024 * 1024 * 1024),
        memoryTotalGb: memoryTotal / (1024 * 1024 * 1024),
        diskTotalGb: diskTotal / (1024 * 1024 * 1024),
        metricsAvailable: true,
      );
    } on Object {
      return base;
    }
  }

  Future<ServerModel> _freeHostMetrics(ServerModel base) async {
    try {
      final raw = await api.applicationMonitoring('dokploy');
      return raw is Map ? _hostFromMonitoring(base, raw) : base;
    } on DokployFailure {
      return base;
    }
  }

  Future<ServerModel> _loadServerMetrics(
    ServerModel base,
    String url,
    String token,
  ) async {
    try {
      final values = _metricList(
        await api
            .serverMetrics(url: url, token: token, dataPoints: 3)
            .timeout(const Duration(seconds: 6)),
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
    } on Object {
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
    final results = await Future.wait<dynamic>([
      _loadBaseServices(),
      deployments(),
    ]);
    final services = results[0] as List<ServiceModel>;
    final recentDeployments = results[1] as List<DeploymentModel>;
    final latest = <String, DeploymentModel>{};
    for (final deployment in recentDeployments) {
      if (deployment.serviceId.isEmpty) continue;
      final current = latest[deployment.serviceId];
      if (current == null || deployment.createdAt.isAfter(current.createdAt)) {
        latest[deployment.serviceId] = deployment;
      }
    }
    return services.map((service) {
      final deployment = latest[service.id];
      return deployment?.status == HealthState.deploying
          ? service.copyWith(status: HealthState.deploying)
          : service;
    }).toList();
  }

  Future<List<ServiceModel>> _loadBaseServices() async {
    try {
      final overview = _list(await api.overviewServices());
      if (overview.isNotEmpty) return _servicesFromOverview(overview);
    } on DokployFailure {
      // overview.services was added in Dokploy 0.30. Fall back to the project
      // hierarchy for older versions and partially upgraded installations.
    }
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
                status: _serviceState(
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

  List<ServiceModel> _servicesFromOverview(List<dynamic> raw) =>
      raw.whereType<Map>().map((service) {
        final kind = _kindFromType(_s(service, ['type']));
        return ServiceModel(
          id: _s(service, ['id']),
          name: _s(service, ['name', 'appName'], 'Service'),
          kind: kind,
          status: _serviceState(service['status']),
          project: _s(service, ['projectName'], 'Production'),
          appName: _s(service, ['appName', 'name']),
          serverId: _s(service, ['serverId']),
          metricsAvailable: false,
        );
      }).toList();

  ServiceKind _kindFromType(String value) => switch (value.toLowerCase()) {
        'compose' => ServiceKind.compose,
        'postgres' => ServiceKind.postgres,
        'mysql' => ServiceKind.mysql,
        'mariadb' => ServiceKind.mariadb,
        'mongo' => ServiceKind.mongo,
        'redis' => ServiceKind.redis,
        _ => ServiceKind.application,
      };

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
      final reportedStatus = _serviceState(
        raw[service.kind == ServiceKind.compose
            ? 'composeStatus'
            : 'applicationStatus'],
      );
      final detailed = service.copyWith(
        name: _s(raw, ['name'], service.name),
        status: reportedStatus == HealthState.unknown
            ? service.status
            : reportedStatus,
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
    final unit = String.fromCharCodes(
      text.toLowerCase().codeUnits.where(
            (codeUnit) => codeUnit >= 97 && codeUnit <= 122,
          ),
    );
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
    final results = await Future.wait<dynamic>([
      services(),
      deployments(),
      projects(),
    ]);
    final ss = results[0] as List<ServiceModel>;
    final ds = results[1] as List<DeploymentModel>;
    final ps = results[2] as List<ProjectModel>;
    return DashboardSnapshot(
        running: ss.where((x) => x.status == HealthState.healthy).length,
        stopped: ss.where((x) => x.status == HealthState.stopped).length,
        failed: ss.where((x) => x.status == HealthState.failed).length,
        projects: ps,
        deployments: ds.take(5).toList(),
        // Server inventory and metrics load progressively through their own
        // provider, so a slow monitor cannot block the first dashboard paint.
        servers: const [],
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

  @override
  Future<TraefikRequestPage> traefikRequests({int limit = 200}) async {
    final enabledRaw = await api.requestsActive();
    final enabled = enabledRaw == true || '$enabledRaw'.toLowerCase() == 'true';
    if (!enabled) {
      return const TraefikRequestPage(
        enabled: false,
        items: [],
        totalCount: 0,
      );
    }
    final raw = await api.traefikRequests(limit: limit);
    final map = raw is Map ? raw : const {};
    final items = _list(map['data']).whereType<Map>().map((entry) {
      final nanos = _d(entry['Duration']);
      return TraefikRequestModel(
        timestamp: DateTime.tryParse(_s(entry, ['StartUTC', 'time'])) ??
            DateTime.now(),
        method: _s(entry, ['RequestMethod'], 'GET'),
        host: _s(entry, ['RequestHost']),
        path: _s(entry, ['RequestPath'], '/'),
        statusCode: _d(entry['DownstreamStatus']).round(),
        durationMs: nanos / 1000000,
        clientHost: _s(entry, ['ClientHost', 'ClientAddr']),
        router: _s(entry, ['RouterName']),
        service: _s(entry, ['ServiceName']),
        protocol: _s(entry, ['RequestProtocol']),
      );
    }).toList();
    return TraefikRequestPage(
      enabled: true,
      items: items,
      totalCount: _d(map['totalCount']).round().clamp(items.length, 1 << 31),
    );
  }

  @override
  Stream<ServerModel> watchControlPlaneMetrics() async* {
    var base = const ServerModel(
      id: 'dokploy-control-plane',
      name: 'Dokploy host',
      host: 'local',
      status: HealthState.healthy,
      cpu: 0,
      memory: 0,
      disk: 0,
      metricsAvailable: false,
      monitoringConfigured: true,
    );
    try {
      final config = await api.metricsConfig();
      if (config is Map) {
        final host = _s(config, ['serverIp']);
        if (host.isNotEmpty) {
          base = ServerModel(
            id: base.id,
            name: base.name,
            host: host,
            status: base.status,
            cpu: 0,
            memory: 0,
            disk: 0,
            metricsAvailable: false,
            monitoringConfigured: true,
          );
        }
      }
    } on DokployFailure {
      // The WebSocket can still provide host stats without paid monitoring.
    }
    while (true) {
      try {
        await for (final message in api.dockerStats(appName: 'dokploy')) {
          if (message is Map && message['data'] is Map) {
            final value = _hostFromMonitoring(base, message['data'] as Map);
            if (value.metricsAvailable) yield value;
          }
        }
      } on Object {
        // Reconnect below after a short backoff.
      }
      await Future<void>.delayed(const Duration(seconds: 3));
    }
  }

  @override
  Stream<ServiceModel> watchServiceMetrics(ServiceModel service) async* {
    if (service.appName.isEmpty ||
        (service.kind != ServiceKind.application &&
            service.kind != ServiceKind.compose)) {
      return;
    }
    final appType =
        service.kind == ServiceKind.compose ? 'docker-compose' : 'application';
    while (true) {
      try {
        await for (final message in api.dockerStats(
          appName: service.appName,
          appType: appType,
          serviceId: service.id,
        )) {
          if (message is Map && message['data'] is Map) {
            yield _serviceFromMonitoring(service, message['data'] as Map);
          }
        }
      } on Object {
        // Reconnect below after a short backoff.
      }
      await Future<void>.delayed(const Duration(seconds: 3));
    }
  }

  ServerModel _hostFromMonitoring(ServerModel base, Map raw) {
    final cpu = _monitoringEntry(raw, 'cpu');
    final memory = _monitoringEntry(raw, 'memory');
    final disk = _monitoringEntry(raw, 'disk');
    final network = _monitoringEntry(raw, 'network');
    final memoryValue = _mapAt(memory, 'value');
    final diskValue = _mapAt(disk, 'value');
    final networkValue = _mapAt(network, 'value');
    final usedMb = _toMegabytes(memoryValue['used']);
    final totalMb = _toMegabytes(memoryValue['total']);
    final diskTotal = _d(diskValue['diskTotal']);
    final hasMetrics = cpu.isNotEmpty || memory.isNotEmpty || disk.isNotEmpty;
    return base.copyWith(
      cpu: _d(cpu['value']),
      memory: totalMb <= 0 ? 0 : usedMb / totalMb * 100,
      disk: _d(diskValue['diskUsedPercentage']),
      metricsAvailable: hasMetrics,
      monitoringConfigured: true,
      memoryUsedGb: usedMb / 1024,
      memoryTotalGb: totalMb / 1024,
      diskTotalGb: diskTotal,
      networkInKbps: _d(networkValue['inputMb']),
      networkOutKbps: _d(networkValue['outputMb']),
    );
  }

  ServiceModel _serviceFromMonitoring(ServiceModel service, Map raw) {
    final cpu = _monitoringEntry(raw, 'cpu');
    final memory = _monitoringEntry(raw, 'memory');
    final network = _monitoringEntry(raw, 'network');
    final memoryValue = _mapAt(memory, 'value');
    final networkValue = _mapAt(network, 'value');
    final timestamps = [cpu, memory, network]
        .map((entry) => DateTime.tryParse(_s(entry, ['time'])))
        .whereType<DateTime>()
        .toList();
    return service.copyWith(
      // Docker only emits this stream while the container is running. A fresh
      // sample is therefore stronger runtime evidence than the persisted
      // application/compose operation status.
      status: HealthState.healthy,
      cpu: _d(cpu['value']),
      memoryMb: _toMegabytes(memoryValue['used']),
      networkReceivedMb: _d(networkValue['inputMb']),
      networkSentMb: _d(networkValue['outputMb']),
      metricsAvailable:
          cpu.isNotEmpty || memory.isNotEmpty || network.isNotEmpty,
      metricsUpdatedAt: timestamps.isEmpty
          ? DateTime.now()
          : timestamps.reduce((a, b) => a.isAfter(b) ? a : b),
    );
  }

  Map _monitoringEntry(Map raw, String key) {
    final value = raw[key];
    if (value is Map) return value;
    if (value is List && value.isNotEmpty && value.last is Map) {
      return value.last as Map;
    }
    return const {};
  }
}
