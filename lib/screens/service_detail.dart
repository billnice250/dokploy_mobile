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
    final service = liveMetrics == null || !liveMetrics.metricsAvailable
        ? detailedService
        : detailedService.copyWith(
            cpu: liveMetrics.cpu,
            memoryMb: liveMetrics.memoryMb,
            networkReceivedMb: liveMetrics.networkReceivedMb,
            networkSentMb: liveMetrics.networkSentMb,
            metricsAvailable: liveMetrics.metricsAvailable,
            metricsUpdatedAt: liveMetrics.metricsUpdatedAt,
          );
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
          Expanded(
            child: switch (tab) {
              0 => _Overview(
                  service,
                  loading: detail.isLoading,
                  error: detail.hasError,
                  onRefresh: () =>
                      ref.invalidate(serviceDetailProvider(listedService)),
                ),
              1 => _Logs(service: service),
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
                  () => ref.read(repositoryProvider).start(service),
                );
              },
            ),
            ListTile(
              enabled: lifecycleAvailable,
              leading: const Icon(Icons.restart_alt),
              title: const Text('Redeploy'),
              onTap: () {
                Navigator.pop(sheetContext);
                _runAction(
                  context,
                  'Redeploy',
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
        () => ref.read(repositoryProvider).stop(service),
      );
    }
  }

  Future<void> _runAction(
    BuildContext context,
    String label,
    Future<void> Function() action,
  ) async {
    final authorized = await confirmSensitiveOperation(
      context,
      ref,
      reason: 'Confirm ${label.toLowerCase()} for this service in DployGo.',
    );
    if (!authorized || !context.mounted) return;
    try {
      await action();
      ref.invalidate(servicesProvider);
      if (context.mounted) {
        DployGoNotice.show(
          context,
          message: '$label requested successfully.',
          tone: DployGoNoticeTone.success,
        );
      }
    } catch (error) {
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

class _Logs extends ConsumerStatefulWidget {
  const _Logs({required this.service});

  final ServiceModel service;

  @override
  ConsumerState<_Logs> createState() => _LogsState();
}

class _LogsState extends ConsumerState<_Logs> {
  int tail = 200;
  String search = '';
  Future<List<String>>? request;

  Future<List<String>> _load() =>
      ref.read(repositoryProvider).logs(widget.service.id, tail: tail);

  void _reload() => setState(() => request = _load());

  @override
  Widget build(BuildContext context) {
    final capabilities = ref.watch(capabilitiesProvider).valueOrNull;
    if (capabilities?.logs == false ||
        widget.service.kind != ServiceKind.application) {
      return const Center(
        child: Text('Logs are unavailable for this service.'),
      );
    }
    request ??= _load();
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
        Expanded(
          child: FutureBuilder<List<String>>(
            future: request,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                    child: Text('Could not load logs: ${snapshot.error}'));
              }
              final lines = (snapshot.data ?? const <String>[])
                  .where((line) =>
                      search.isEmpty || line.toLowerCase().contains(search))
                  .toList();
              return Container(
                color: const Color(0xFF070708),
                child: ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: lines.length,
                  itemBuilder: (context, index) => GestureDetector(
                    onLongPress: () async {
                      await Clipboard.setData(
                          ClipboardData(text: lines[index]));
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
            },
          ),
        ),
      ],
    );
  }

  Color _logColor(String line) {
    final normalized = line.toLowerCase();
    if (normalized.contains('error') || normalized.contains('fatal')) {
      return const Color(0xFFFCA5A5);
    }
    if (normalized.contains('warn')) return const Color(0xFFFCD34D);
    return const Color(0xFFD6D6DA);
  }
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

class _Config extends StatelessWidget {
  const _Config(this.service);

  final ServiceModel service;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text(
            'Configuration',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Read-only in v0.1'),
              subtitle: Text(
                'Configuration editing stays hidden until its API contract and secret handling are validated.',
              ),
            ),
          ),
        ],
      );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
