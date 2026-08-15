import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../domain/models.dart';

class ServersScreen extends ConsumerWidget {
  const ServersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servers = ref.watch(serversProvider);
    final instance = ref.watch(currentInstanceProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Servers'),
        actions: [
          IconButton(
            tooltip: 'Refresh metrics',
            onPressed: () => ref.invalidate(serversProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: servers.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (items) => items.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline,
                          size: 36, color: DokployTheme.muted),
                      SizedBox(height: 12),
                      Text(
                        'Server inventory unavailable',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'This API token may not include server access.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: DokployTheme.muted),
                      ),
                    ],
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
                children: [
                  for (final server in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GlassPanel(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                StatusDot(server.status),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        server.name,
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        server.host,
                                        style: const TextStyle(
                                            color: DokployTheme.muted),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            if (!server.metricsAvailable) ...[
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                  Icons.monitor_heart_outlined,
                                  color: DokployTheme.muted,
                                ),
                                title: Text(server.monitoringConfigured
                                    ? 'Waiting for monitoring data'
                                    : 'Monitoring is not enabled'),
                                subtitle: Text(
                                  server.monitoringConfigured
                                      ? 'The collector is configured but has not returned a sample yet.'
                                      : 'Enable Dokploy monitoring to collect CPU, memory and storage usage.',
                                  style: const TextStyle(
                                      color: DokployTheme.muted),
                                ),
                              ),
                              if (!instance.demo &&
                                  !server.monitoringConfigured)
                                FilledButton.icon(
                                  onPressed: () =>
                                      _enableMonitoring(context, ref, server),
                                  icon:
                                      const Icon(Icons.monitor_heart_outlined),
                                  label: const Text('Enable monitoring'),
                                ),
                            ] else ...[
                              ProgressMetric(label: 'CPU', value: server.cpu),
                              const SizedBox(height: 14),
                              ProgressMetric(
                                  label: 'Memory', value: server.memory),
                              if (server.memoryTotalGb > 0) ...[
                                const SizedBox(height: 5),
                                Text(
                                  '${server.memoryUsedGb.toStringAsFixed(1)} GB of ${server.memoryTotalGb.toStringAsFixed(1)} GB',
                                  style: const TextStyle(
                                    color: DokployTheme.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 14),
                              ProgressMetric(
                                  label: 'Storage', value: server.disk),
                              if (server.diskTotalGb > 0) ...[
                                const SizedBox(height: 5),
                                Text(
                                  '${server.diskUsedGb.toStringAsFixed(1)} GB used of ${server.diskTotalGb.toStringAsFixed(1)} GB  •  ${server.diskFreeGb.toStringAsFixed(1)} GB free',
                                  style: const TextStyle(
                                    color: DokployTheme.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  Expanded(
                                    child: _NetworkValue(
                                      icon: Icons.south,
                                      label: 'Network in',
                                      value: server.networkInKbps,
                                    ),
                                  ),
                                  Expanded(
                                    child: _NetworkValue(
                                      icon: Icons.north,
                                      label: 'Network out',
                                      value: server.networkOutKbps,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (!instance.demo) ...[
                              const SizedBox(height: 18),
                              const Divider(),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _clearStorage(context, ref, server),
                                  icon: const Icon(
                                      Icons.cleaning_services_outlined),
                                  label: const Text('Clear unused storage'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Future<void> _enableMonitoring(
    BuildContext context,
    WidgetRef ref,
    ServerModel server,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Enable monitoring on ${server.name}?'),
        content: const Text(
          'Dokploy will install or configure its metrics collector. The first CPU, memory and storage sample can take about one minute.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Enable'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _runMutation(
      context,
      () => ref.read(repositoryProvider).setupMonitoring(
            serverId: server.id == 'dokploy-control-plane' ? null : server.id,
          ),
      success: 'Monitoring enabled. Refresh after the first sample arrives.',
      ref: ref,
    );
  }

  Future<void> _clearStorage(
    BuildContext context,
    WidgetRef ref,
    ServerModel server,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded,
            color: DokployTheme.warning),
        title: Text('Clear unused storage on ${server.name}?'),
        content: const Text(
          'This runs Dokploy Docker Prune. It can permanently remove stopped containers, unused images, unused networks and build cache. Running services are not intentionally stopped, but removed data cannot be restored.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: DokployTheme.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear unused storage'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _runMutation(
      context,
      () => ref.read(repositoryProvider).pruneDocker(
            serverId: server.id == 'dokploy-control-plane' ? null : server.id,
          ),
      success: 'Docker cleanup completed. Storage updates on the next sample.',
      ref: ref,
    );
  }

  Future<void> _runMutation(
    BuildContext context,
    Future<void> Function() operation, {
    required String success,
    required WidgetRef ref,
  }) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await operation();
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ref.invalidate(serversProvider);
      ref.invalidate(dashboardProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success)),
      );
    } catch (error) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Operation failed: $error')),
      );
    }
  }
}

class _NetworkValue extends StatelessWidget {
  const _NetworkValue({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 17, color: DokployTheme.muted),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style:
                      const TextStyle(color: DokployTheme.muted, fontSize: 11)),
              Text('${value.toStringAsFixed(1)} MB'),
            ],
          ),
        ],
      );
}
