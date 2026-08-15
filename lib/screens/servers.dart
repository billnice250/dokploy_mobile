import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

class ServersScreen extends ConsumerWidget {
  const ServersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servers = ref.watch(serversProvider);
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
                            if (!server.metricsAvailable)
                              const ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  Icons.monitor_heart_outlined,
                                  color: DokployTheme.muted,
                                ),
                                title: Text('Live metrics unavailable'),
                                subtitle: Text(
                                  'Configure Monitoring for this server in Dokploy, then wait for the first sample.',
                                  style: TextStyle(color: DokployTheme.muted),
                                ),
                              )
                            else ...[
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
                              ProgressMetric(label: 'Disk', value: server.disk),
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
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
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
              Text('${value.toStringAsFixed(1)} KB/s'),
            ],
          ),
        ],
      );
}
