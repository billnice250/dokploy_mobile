import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers.dart';
import '../core/app_notice.dart';
import '../core/biometric_confirmation.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../domain/models.dart';

class ServiceDetailScreen extends ConsumerStatefulWidget {
  const ServiceDetailScreen({super.key, required this.serviceId});

  final String serviceId;

  @override
  ConsumerState<ServiceDetailScreen> createState() => _ServiceDetailState();
}

class _ServiceDetailState extends ConsumerState<ServiceDetailScreen> {
  int tab = 0;
  String? _selectedContainerKey;
  Timer? _containerRefreshTimer;
  HealthState? _optimisticStatus;
  DateTime? _optimisticStatusUntil;

  @override
  void initState() {
    super.initState();
    _containerRefreshTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => ref.invalidate(serviceContainersProvider),
    );
  }

  @override
  void dispose() {
    _containerRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final capabilities = ref.watch(capabilitiesProvider).valueOrNull;
    final services =
        ref.watch(servicesProvider).valueOrNull ?? const <ServiceModel>[];
    final listedService =
        services.where((item) => item.id == widget.serviceId).firstOrNull;
    if (listedService == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Service not found')),
      );
    }
    final detail = ref.watch(serviceDetailProvider(listedService));
    final detailedService = detail.valueOrNull ?? listedService;
    final liveMetrics =
        ref.watch(liveServiceMetricsProvider(detailedService)).valueOrNull;
    final metricsUpdatedAt = liveMetrics?.metricsUpdatedAt;
    final hasFreshRuntimeSample = liveMetrics?.metricsAvailable == true &&
        metricsUpdatedAt != null &&
        DateTime.now().difference(metricsUpdatedAt).abs() <
            const Duration(seconds: 7);
    final optimisticStatus =
        _optimisticStatusUntil?.isAfter(DateTime.now()) == true
            ? _optimisticStatus
            : null;
    final runtimeStatus = detailedService.status == HealthState.deploying
        ? HealthState.deploying
        : hasFreshRuntimeSample
            ? liveMetrics!.status
            : detailedService.status;
    final service = liveMetrics == null || !liveMetrics.metricsAvailable
        ? detailedService.copyWith(status: optimisticStatus ?? runtimeStatus)
        : detailedService.copyWith(
            status: optimisticStatus ?? runtimeStatus,
            cpu: liveMetrics.cpu,
            memoryMb: liveMetrics.memoryMb,
            networkReceivedMb: liveMetrics.networkReceivedMb,
            networkSentMb: liveMetrics.networkSentMb,
            metricsAvailable: liveMetrics.metricsAvailable,
            metricsUpdatedAt: liveMetrics.metricsUpdatedAt,
          );
    final containerRequest = ref.watch(serviceContainersProvider(service));
    final containers =
        containerRequest.valueOrNull ?? const <ContainerInstance>[];
    final selectedContainer = containers
            .where((item) => _containerKey(item) == _selectedContainerKey)
            .firstOrNull ??
        containers.firstOrNull;
    final lifecycleAvailable =
        capabilities?.lifecycle == true && _supportsLifecycle(service.kind);
    return Scaffold(
      appBar: AppBar(
        title: Text(service.name),
        actions: [
          IconButton(
            onPressed: () => _showActions(
              context,
              service,
              lifecycleAvailable: lifecycleAvailable,
            ),
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                StatusDot(service.status),
                const SizedBox(width: 8),
                Text(
                  statusLabel(service.status),
                  style: TextStyle(color: statusColor(service.status)),
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: lifecycleAvailable
                      ? () => _runAction(
                            context,
                            'Redeploy',
                            service,
                            () =>
                                ref.read(repositoryProvider).redeploy(service),
                          )
                      : null,
                  icon: const Icon(Icons.rocket_launch_outlined),
                  label: const Text('Redeploy'),
                ),
              ],
            ),
          ),
          NavigationBar(
            height: 64,
            selectedIndex: tab,
            onDestinationSelected: (index) => setState(() => tab = index),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                label: 'Overview',
              ),
              NavigationDestination(icon: Icon(Icons.subject), label: 'Logs'),
              NavigationDestination(
                  icon: Icon(Icons.history), label: 'Deploys'),
              NavigationDestination(icon: Icon(Icons.tune), label: 'Config'),
            ],
          ),
          _ContainerSelector(
            containers: containers,
            selected: selectedContainer,
            loading: containerRequest.isLoading,
            onSelected: (value) => setState(
              () => _selectedContainerKey = _containerKey(value),
            ),
          ),
          Expanded(
            child: switch (tab) {
              0 => _Overview(
                  service,
                  loading: detail.isLoading,
                  error: detail.hasError,
                  onRefresh: () =>
                      ref.invalidate(serviceDetailProvider(listedService)),
                ),
              1 => _Logs(service: service, container: selectedContainer),
              2 => _Deploys(serviceId: service.id),
              _ => _Config(service),
            },
          ),
        ],
      ),
    );
  }

  void _showActions(BuildContext context, ServiceModel service,
      {required bool lifecycleAvailable}) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              enabled: lifecycleAvailable,
              leading: const Icon(Icons.play_arrow),
              title: const Text('Start'),
              onTap: () {
                Navigator.pop(sheetContext);
                _runAction(
                  context,
                  'Start',
                  service,
                  () => ref.read(repositoryProvider).start(service),
                );
              },
            ),
            ListTile(
              enabled: lifecycleAvailable,
              leading: const Icon(Icons.restart_alt),
              title: const Text('Restart'),
              subtitle: const Text('Stop, then start immediately'),
              onTap: () {
                Navigator.pop(sheetContext);
                _runAction(
                  context,
                  'Restart',
                  service,
                  () => ref.read(repositoryProvider).restart(service),
                );
              },
            ),
            ListTile(
              enabled: lifecycleAvailable,
              leading: const Icon(Icons.rocket_launch_outlined),
              title: const Text('Redeploy'),
              onTap: () {
                Navigator.pop(sheetContext);
                _runAction(
                  context,
                  'Redeploy',
                  service,
                  () => ref.read(repositoryProvider).redeploy(service),
                );
              },
            ),
            ListTile(
              enabled: lifecycleAvailable,
              leading: const Icon(Icons.stop, color: DokployTheme.danger),
              title: const Text('Stop'),
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmStop(context, service);
              },
            ),
            const Divider(),
            const ListTile(
              enabled: false,
              leading: Icon(Icons.terminal),
              title: Text('Terminal'),
              subtitle:
                  Text('Unavailable until the server capability is verified'),
              trailing: UpcomingBadge(),
            ),
          ],
        ),
      ),
    );
  }

  bool _supportsLifecycle(ServiceKind kind) =>
      kind == ServiceKind.application ||
      kind == ServiceKind.compose ||
      kind == ServiceKind.postgres;

  Future<void> _confirmStop(BuildContext context, ServiceModel service) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Stop ${service.name}?'),
        content: const Text(
            'The service will be unavailable until it is started again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: DokployTheme.danger),
            child: const Text('Stop service'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await _runAction(
        context,
        'Stop',
        service,
        () => ref.read(repositoryProvider).stop(service),
      );
    }
  }

  Future<void> _runAction(
    BuildContext context,
    String label,
    ServiceModel service,
    Future<void> Function() action,
  ) async {
    final authorized = await confirmSensitiveOperation(
      context,
      ref,
      reason: 'Confirm ${label.toLowerCase()} for this service in DployGo.',
    );
    if (!authorized || !context.mounted) return;
    setState(() {
      _optimisticStatus = switch (label) {
        'Stop' => HealthState.stopped,
        'Restart' => HealthState.restarting,
        _ => HealthState.deploying,
      };
      _optimisticStatusUntil = DateTime.now().add(const Duration(seconds: 15));
    });
    try {
      await action();
      ref.invalidate(servicesProvider);
      ref.invalidate(deploymentsProvider);
      ref.invalidate(dashboardProvider);
      ref.invalidate(serviceDetailProvider(service));
      ref.invalidate(liveServiceMetricsProvider(service));
      if (context.mounted) {
        DployGoNotice.show(
          context,
          message: '$label requested successfully.',
          tone: DployGoNoticeTone.success,
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _optimisticStatus = null;
          _optimisticStatusUntil = null;
        });
      }
      if (context.mounted) {
        DployGoNotice.show(
          context,
          message: '$label failed: $error',
          tone: DployGoNoticeTone.error,
        );
      }
    }
  }
}

class _Overview extends StatelessWidget {
  const _Overview(
    this.service, {
    required this.loading,
    required this.error,
    required this.onRefresh,
  });

  final ServiceModel service;
  final bool loading, error;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final valueUnavailable = loading ? '…' : '—';
    final hasMetrics = service.metricsAvailable;
    final updatedAt = service.metricsUpdatedAt;
    final stale = updatedAt != null &&
        DateTime.now().difference(updatedAt.toLocal()) >
            const Duration(minutes: 5);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (loading) const LinearProgressIndicator(minHeight: 2),
        if (!loading && (!hasMetrics || stale || error)) ...[
          Card(
            child: ListTile(
              leading: Icon(
                error ? Icons.sync_problem : Icons.monitor_heart_outlined,
              ),
              title: Text(
                error
                    ? 'Could not refresh container metrics'
                    : !hasMetrics
                        ? 'Container metrics are unavailable'
                        : 'The latest sample is stale',
              ),
              subtitle: Text(
                updatedAt == null
                    ? 'Dokploy has not returned a sample for this container.'
                    : 'Last sample ${_relativeTime(updatedAt)}',
              ),
              trailing: IconButton(
                tooltip: 'Refresh',
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          // A fixed vertical extent keeps the icon, value and label visible on
          // compact iPhones instead of shrinking cards as the width narrows.
          mainAxisExtent: 150,
          children: [
            MetricCard(
              label: 'CPU',
              value: hasMetrics
                  ? '${service.cpu.toStringAsFixed(1)}%'
                  : valueUnavailable,
              icon: Icons.memory,
            ),
            MetricCard(
              label: 'Memory',
              value: hasMetrics
                  ? _formatMegabytes(service.memoryMb)
                  : valueUnavailable,
              icon: Icons.storage,
            ),
            MetricCard(
              label: 'Received',
              value: hasMetrics
                  ? _formatMegabytes(service.networkReceivedMb)
                  : valueUnavailable,
              icon: Icons.south,
            ),
            MetricCard(
              label: 'Sent',
              value: hasMetrics
                  ? _formatMegabytes(service.networkSentMb)
                  : valueUnavailable,
              icon: Icons.north,
            ),
          ],
        ),
        const SectionTitle('Runtime'),
        Card(
          child: Column(
            children: [
              ListTile(
                  title: const Text('Type'), trailing: Text(service.kind.name)),
              ListTile(
                title: const Text('Image'),
                subtitle: Text(
                    service.image.isEmpty ? 'Not reported' : service.image),
              ),
              if (service.domain.isNotEmpty)
                ListTile(
                    title: const Text('Domain'),
                    subtitle: Text(service.domain)),
            ],
          ),
        ),
      ],
    );
  }
}

String _formatMegabytes(double value) {
  if (value >= 1024) return '${(value / 1024).toStringAsFixed(2)} GB';
  if (value >= 1) return '${value.toStringAsFixed(1)} MB';
  return '${(value * 1024).toStringAsFixed(1)} KB';
}

String _relativeTime(DateTime timestamp) {
  final local = timestamp.toLocal();
  final difference = DateTime.now().difference(local);
  if (difference.isNegative || difference.inMinutes < 1) return 'just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
  if (difference.inHours < 24) return '${difference.inHours} hr ago';
  return '${difference.inDays} days ago';
}

String _containerKey(ContainerInstance container) =>
    '${container.runType}:${container.id}';

class _ContainerSelector extends StatelessWidget {
  const _ContainerSelector({
    required this.containers,
    required this.selected,
    required this.loading,
    required this.onSelected,
  });

  final List<ContainerInstance> containers;
  final ContainerInstance? selected;
  final bool loading;
  final ValueChanged<ContainerInstance> onSelected;

  @override
  Widget build(BuildContext context) {
    if (loading && containers.isEmpty) {
      return const LinearProgressIndicator(minHeight: 2);
    }
    if (containers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Text(
          'No containers currently reported',
          style: TextStyle(color: DokployTheme.muted, fontSize: 12),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: DropdownButtonFormField<String>(
        key: ValueKey(selected == null ? 'none' : _containerKey(selected!)),
        initialValue: selected == null ? null : _containerKey(selected!),
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Container',
          prefixIcon: Icon(Icons.dns_outlined),
          isDense: true,
        ),
        items: [
          for (final container in containers)
            DropdownMenuItem(
              value: _containerKey(container),
              child: Row(
                children: [
                  StatusDot(
                    container.running
                        ? HealthState.healthy
                        : HealthState.stopped,
                    size: 7,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${container.name}  •  ${container.id}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                  if (container.node.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(
                      container.node,
                      style: const TextStyle(
                        color: DokployTheme.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
        onChanged: (key) {
          if (key == null) return;
          final value = containers
              .where((container) => _containerKey(container) == key)
              .firstOrNull;
          if (value != null) onSelected(value);
        },
      ),
    );
  }
}

class _Logs extends ConsumerStatefulWidget {
  const _Logs({required this.service, required this.container});

  final ServiceModel service;
  final ContainerInstance? container;

  @override
  ConsumerState<_Logs> createState() => _LogsState();
}

class _LogsState extends ConsumerState<_Logs> {
  int tail = 200;
  String search = '';
  _LogStatus status = _LogStatus.all;
  Future<List<String>>? request;
  Stream<List<String>>? liveRequest;

  Future<List<String>> _load() =>
      ref.read(repositoryProvider).logs(widget.service.id, tail: tail);

  @override
  void initState() {
    super.initState();
    _resetRequest();
  }

  @override
  void didUpdateWidget(covariant _Logs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.container?.id != widget.container?.id ||
        oldWidget.container?.runType != widget.container?.runType) {
      _resetRequest();
    }
  }

  void _resetRequest() {
    final container = widget.container;
    if (container == null) {
      liveRequest = null;
      request = _load();
    } else {
      request = null;
      liveRequest = ref.read(repositoryProvider).watchContainerLogs(
            widget.service,
            container,
            tail: tail,
          );
    }
  }

  void _reload() => setState(_resetRequest);

  @override
  Widget build(BuildContext context) {
    final capabilities = ref.watch(capabilitiesProvider).valueOrNull;
    if (capabilities?.logs == false) {
      return const Center(
        child: Text('Logs are unavailable for this service.'),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (value) =>
                      setState(() => search = value.toLowerCase()),
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search loaded logs',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<int>(
                tooltip: 'Tail count',
                initialValue: tail,
                onSelected: (value) {
                  tail = value;
                  _reload();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 100, child: Text('Last 100')),
                  PopupMenuItem(value: 200, child: Text('Last 200')),
                  PopupMenuItem(value: 500, child: Text('Last 500')),
                  PopupMenuItem(value: 1000, child: Text('Last 1,000')),
                ],
                child: Chip(label: Text('$tail lines')),
              ),
              IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Row(
            children: [
              for (final value in _LogStatus.values) ...[
                FilterChip(
                  selected: status == value,
                  label: Text(value.label),
                  avatar: value == _LogStatus.all
                      ? null
                      : Icon(Icons.circle, size: 9, color: value.color),
                  onSelected: (_) => setState(() => status = value),
                ),
                const SizedBox(width: 7),
              ],
            ],
          ),
        ),
        Expanded(
          child: liveRequest == null
              ? FutureBuilder<List<String>>(
                  future: request,
                  builder: (context, snapshot) => _logResult(
                    snapshot.connectionState,
                    snapshot.data,
                    snapshot.error,
                  ),
                )
              : StreamBuilder<List<String>>(
                  stream: liveRequest,
                  builder: (context, snapshot) => _logResult(
                    snapshot.connectionState,
                    snapshot.data,
                    snapshot.error,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _logResult(
    ConnectionState connection,
    List<String>? data,
    Object? error,
  ) {
    if (error != null) {
      return Center(child: Text('Could not load logs: $error'));
    }
    if (data == null && connection == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    final lines = (data ?? const <String>[])
        .where((line) => search.isEmpty || line.toLowerCase().contains(search))
        .where((line) => status == _LogStatus.all || _logStatus(line) == status)
        .toList();
    return Container(
      color: const Color(0xFF070708),
      child: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: lines.length,
        itemBuilder: (context, index) => GestureDetector(
          onLongPress: () async {
            await Clipboard.setData(ClipboardData(text: lines[index]));
            if (context.mounted) {
              DployGoNotice.show(
                context,
                message: 'Log line copied.',
                tone: DployGoNoticeTone.success,
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: SelectableText(
              lines[index],
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.2,
                color: _logColor(lines[index]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _logColor(String line) {
    return _logStatus(line).color;
  }
}

enum _LogStatus {
  all('All', Color(0xFFD6D6DA)),
  info('Info / success', Color(0xFFD6D6DA)),
  warning('Warning / 4xx', DokployTheme.warning),
  error('Error / 5xx', DokployTheme.danger);

  const _LogStatus(this.label, this.color);
  final String label;
  final Color color;
}

_LogStatus _logStatus(String line) {
  final normalized = line.toLowerCase();
  if (normalized.contains('error') ||
      normalized.contains('fatal') ||
      normalized.contains('panic') ||
      _containsHttpStatus(line, 5)) {
    return _LogStatus.error;
  }
  if (normalized.contains('warn') || _containsHttpStatus(line, 4)) {
    return _LogStatus.warning;
  }
  return _LogStatus.info;
}

bool _containsHttpStatus(String line, int statusClass) {
  var digits = '';
  for (final codeUnit in line.codeUnits) {
    final isDigit = codeUnit >= 48 && codeUnit <= 57;
    if (isDigit) {
      digits += String.fromCharCode(codeUnit);
    } else {
      if (digits.length == 3 && int.parse(digits) ~/ 100 == statusClass) {
        return true;
      }
      digits = '';
    }
  }
  return digits.length == 3 && int.parse(digits) ~/ 100 == statusClass;
}

class _Deploys extends ConsumerWidget {
  const _Deploys({required this.serviceId});

  final String serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deployments = (ref.watch(deploymentsProvider).valueOrNull ??
            const <DeploymentModel>[])
        .where((deployment) => deployment.serviceId == serviceId)
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final deployment in deployments)
          Card(
            child: ListTile(
              onTap: () => context.push('/deployment/${deployment.id}'),
              leading: StatusDot(deployment.status),
              title: Text(deployment.commit.isEmpty
                  ? deployment.id
                  : deployment.commit),
              subtitle: Text('${deployment.branch} • ${deployment.message}'),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
        if (deployments.isEmpty)
          const Center(child: Text('No deployments found for this service.')),
      ],
    );
  }
}

class _Config extends ConsumerStatefulWidget {
  const _Config(this.service);

  final ServiceModel service;

  @override
  ConsumerState<_Config> createState() => _ConfigState();
}

class _ConfigState extends ConsumerState<_Config> {
  final List<_EnvironmentRow> _rows = [];
  final List<String> _preservedLines = [];
  ServiceEnvironment? _environment;
  String _originalEnvironment = '';
  Object? _error;
  bool _loading = false;
  bool _saving = false;
  bool _revealed = false;

  @override
  void didUpdateWidget(covariant _Config oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service.id != widget.service.id) _hide();
  }

  @override
  void dispose() {
    _disposeRows();
    super.dispose();
  }

  void _hide() {
    _disposeRows();
    _preservedLines.clear();
    _environment = null;
    _originalEnvironment = '';
    _error = null;
    _revealed = false;
  }

  Future<void> _requestHide() async {
    if (_hasChanges) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Discard environment changes?'),
          content: const Text('Your unsaved key/value changes will be lost.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    setState(_hide);
  }

  void _disposeRows() {
    for (final row in _rows) {
      row.dispose();
    }
    _rows.clear();
  }

  void _readEnvironment(String source) {
    _disposeRows();
    _preservedLines.clear();
    for (final line in source.split('\n')) {
      final trimmed = line.trim();
      final separator = line.indexOf('=');
      if (trimmed.isEmpty || trimmed.startsWith('#') || separator <= 0) {
        if (line.isNotEmpty) _preservedLines.add(line);
        continue;
      }
      final key = line.substring(0, separator).trim();
      if (!_validEnvironmentKey(key)) {
        _preservedLines.add(line);
        continue;
      }
      _rows.add(
        _EnvironmentRow(
          key: key,
          value: line.substring(separator + 1),
        ),
      );
    }
    _originalEnvironment = _serializeEnvironment();
  }

  String _serializeEnvironment() => [
        ..._preservedLines,
        ..._rows.map((row) => '${row.key.text.trim()}=${row.value.text}'),
      ].join('\n');

  String? get _validationMessage {
    final seen = <String>{};
    for (final row in _rows) {
      final key = row.key.text.trim();
      if (key.isEmpty) return 'Every variable needs a key.';
      if (!_validEnvironmentKey(key)) return '“$key” is not a valid env key.';
      if (!seen.add(key)) return 'The key “$key” is duplicated.';
    }
    return null;
  }

  bool get _hasChanges =>
      _environment != null && _serializeEnvironment() != _originalEnvironment;

  Future<void> _reveal() async {
    final authorized = await confirmSensitiveOperation(
      context,
      ref,
      reason: 'Reveal environment secrets for ${widget.service.name}.',
    );
    if (!authorized || !mounted) return;
    setState(() {
      _revealed = true;
      _loading = true;
      _error = null;
    });
    try {
      final value =
          await ref.read(repositoryProvider).environment(widget.service);
      if (!mounted) return;
      setState(() {
        _environment = value;
        _readEnvironment(value.env);
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final current = _environment;
    if (current == null || !_hasChanges || _validationMessage != null) return;
    final authorized = await confirmSensitiveOperation(
      context,
      ref,
      reason: 'Save environment secrets for ${widget.service.name}.',
    );
    if (!authorized || !mounted) return;
    setState(() => _saving = true);
    try {
      final serialized = _serializeEnvironment();
      final updated = current.copyWith(env: serialized);
      await ref
          .read(repositoryProvider)
          .saveEnvironment(widget.service, updated);
      if (!mounted) return;
      setState(() {
        _environment = updated;
        _originalEnvironment = serialized;
      });
      DployGoNotice.show(
        context,
        message: 'Environment saved. Restart or redeploy to apply it.',
        tone: DployGoNoticeTone.success,
      );
    } catch (error) {
      if (mounted) {
        DployGoNotice.show(
          context,
          message: 'Could not save environment: $error',
          tone: DployGoNoticeTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          if (_hasChanges) _pinnedChangeBanner(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Configuration',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                if (!_revealed)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.key_outlined),
                      title: const Text('Environment variables'),
                      subtitle: const Text(
                        'Values are protected by biometric confirmation and never written to app logs.',
                      ),
                      trailing: FilledButton.tonalIcon(
                        onPressed: _reveal,
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('Reveal'),
                      ),
                    ),
                  )
                else ...[
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Environment variables',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _requestHide,
                        icon: const Icon(Icons.visibility_off_outlined),
                        label: const Text('Hide'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_loading)
                    const Center(child: CircularProgressIndicator())
                  else if (_error != null)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.error_outline),
                        title: const Text('Could not load environment'),
                        subtitle: Text('$_error'),
                        trailing: IconButton(
                          onPressed: _reveal,
                          icon: const Icon(Icons.refresh),
                        ),
                      ),
                    )
                  else ...[
                    for (var index = 0; index < _rows.length; index++)
                      _environmentRow(_rows[index], index),
                    if (_rows.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text(
                            'No environment variables configured.',
                            style: TextStyle(color: DokployTheme.muted),
                          ),
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => setState(
                        () => _rows.add(_EnvironmentRow()),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Add variable'),
                    ),
                    if (_preservedLines.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        '${_preservedLines.length} comment or advanced line(s) are preserved unchanged.',
                        style: const TextStyle(
                          color: DokployTheme.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (_validationMessage case final message?) ...[
                      const SizedBox(height: 10),
                      Text(
                        message,
                        style: const TextStyle(color: DokployTheme.danger),
                      ),
                    ],
                    const SizedBox(height: 10),
                    const Text(
                      'Saving does not restart the service. Apply changes with Restart or Redeploy.',
                      style: TextStyle(color: DokployTheme.muted, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed:
                          _saving || !_hasChanges || _validationMessage != null
                              ? null
                              : _save,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(_saving ? 'Saving…' : 'Save environment'),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      );

  Widget _pinnedChangeBanner() => Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: DokployTheme.warning.withValues(alpha: .12),
          border: Border.all(
            color: DokployTheme.warning.withValues(alpha: .55),
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .22),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: DokployTheme.warning,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Unsaved environment changes',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );

  Widget _environmentRow(_EnvironmentRow row, int index) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final keyField = TextField(
                controller: row.key,
                onChanged: (_) => setState(() {}),
                autocorrect: false,
                enableSuggestions: false,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Key',
                  hintText: 'API_TOKEN',
                  isDense: true,
                ),
              );
              final valueField = TextField(
                controller: row.value,
                onChanged: (_) => setState(() {}),
                autocorrect: false,
                enableSuggestions: false,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Value',
                  hintText: 'value',
                  isDense: true,
                ),
              );
              final remove = IconButton(
                tooltip: 'Remove variable',
                onPressed: () => setState(() {
                  final removed = _rows.removeAt(index);
                  removed.dispose();
                }),
                icon: const Icon(Icons.delete_outline),
                color: DokployTheme.danger,
              );
              if (constraints.maxWidth < 480) {
                return Column(
                  children: [
                    Row(children: [Expanded(child: keyField), remove]),
                    const SizedBox(height: 9),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: valueField,
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(flex: 4, child: keyField),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('='),
                  ),
                  Expanded(flex: 5, child: valueField),
                  remove,
                ],
              );
            },
          ),
        ),
      );
}

class _EnvironmentRow {
  _EnvironmentRow({String key = '', String value = ''})
      : key = TextEditingController(text: key),
        value = TextEditingController(text: value);

  final TextEditingController key;
  final TextEditingController value;

  void dispose() {
    key.dispose();
    value.dispose();
  }
}

bool _validEnvironmentKey(String value) {
  if (value.isEmpty) return false;
  bool letterOrUnderscore(int unit) =>
      unit == 95 || (unit >= 65 && unit <= 90) || (unit >= 97 && unit <= 122);
  bool digit(int unit) => unit >= 48 && unit <= 57;
  final units = value.codeUnits;
  if (!letterOrUnderscore(units.first)) return false;
  return units.skip(1).every((unit) => letterOrUnderscore(unit) || digit(unit));
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
