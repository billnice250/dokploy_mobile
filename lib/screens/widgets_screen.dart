import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../core/home_widget_bridge.dart';
import '../core/theme.dart';
import '../domain/models.dart';

class WidgetsScreen extends ConsumerWidget {
  const WidgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(dashboardProvider);
    final serverState = ref.watch(serversProvider);
    final instance = ref.watch(currentInstanceProvider);
    final platform = Theme.of(context).platform;
    final addInstructions = switch (platform) {
      TargetPlatform.iOS ||
      TargetPlatform.macOS =>
        'Touch and hold the Home Screen, tap Edit, choose Add Widget, then select DployGo Status, Server Metrics, or All-in-One.',
      _ =>
        'Touch and hold an empty area of the Home Screen, open Widgets, then add DployGo Status, Server Metrics, or All-in-One.',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Home screen widget')),
      body: snapshot.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load widget data: $error'),
          ),
        ),
        data: (data) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const Text(
              'At a glance',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose a focused widget or see service health and server usage together in All-in-One.',
              style: TextStyle(color: DokployTheme.muted),
            ),
            const SizedBox(height: 18),
            _WidgetPreview(data: data, instanceName: instance.name),
            const SizedBox(height: 12),
            _ServerMetricsPreview(
              server: serverState.valueOrNull
                  ?.where((item) => item.metricsAvailable)
                  .firstOrNull,
            ),
            const SizedBox(height: 12),
            _CombinedWidgetPreview(
              data: data,
              instanceName: instance.name,
              server: serverState.valueOrNull
                  ?.where((item) => item.metricsAvailable)
                  .firstOrNull,
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.add_to_home_screen_outlined),
                        SizedBox(width: 10),
                        Text(
                          'Add the widget',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(addInstructions),
                    const SizedBox(height: 12),
                    const Text(
                      'Widgets show the last data loaded by DployGo. Open or refresh the app to update them. Tapping a widget opens DployGo.',
                      style: TextStyle(
                        color: DokployTheme.muted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: () async {
                        ref.invalidate(dashboardProvider);
                        ref.invalidate(serversProvider);
                        final summary =
                            await ref.read(dashboardProvider.future);
                        final servers = await ref.read(serversProvider.future);
                        final server = servers
                            .where((item) => item.metricsAvailable)
                            .firstOrNull;
                        await HomeWidgetBridge.update(
                          instanceName: instance.name,
                          running: summary.running,
                          stopped: summary.stopped,
                          failed: summary.failed,
                          serverName: server?.name ?? '',
                          cpuPercent: server?.cpu,
                          diskPercent: server?.disk,
                          diskUsedGb: server?.diskUsedGb,
                          diskTotalGb: server?.diskTotalGb,
                        );
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh widget data'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline, size: 17),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Widgets share the instance label, service counts, and server name with CPU and disk metrics. API keys, server URLs, and raw responses are not shared.',
                    style: TextStyle(color: DokployTheme.muted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WidgetPreview extends StatelessWidget {
  const _WidgetPreview({required this.data, required this.instanceName});

  final DashboardSnapshot data;
  final String instanceName;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 176),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: DokployTheme.backgroundOf(context),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: DokployTheme.borderOf(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.water,
                    size: 17, color: DokployTheme.foregroundOf(context)),
                const SizedBox(width: 8),
                Text(
                  'DPLOYGO  •  INFRASTRUCTURE',
                  style: TextStyle(
                    color: DokployTheme.mutedOf(context),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .8,
                  ),
                ),
                const Spacer(),
                Icon(
                  data.failed > 0
                      ? Icons.error_rounded
                      : Icons.check_circle_rounded,
                  size: 18,
                  color: data.failed > 0
                      ? DokployTheme.warning
                      : DokployTheme.success,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              instanceName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: DokployTheme.foregroundOf(context),
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _WidgetMetric('RUNNING', data.running, DokployTheme.success),
                _WidgetMetric('STOPPED', data.stopped, DokployTheme.warning),
                _WidgetMetric('FAILED', data.failed, DokployTheme.danger),
              ],
            ),
          ],
        ),
      );
}

class _WidgetMetric extends StatelessWidget {
  const _WidgetMetric(this.label, this.value, this.color);

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: TextStyle(
                color: color,
                fontSize: 25,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: DokployTheme.mutedOf(context),
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: .5,
              ),
            ),
          ],
        ),
      );
}

class _ServerMetricsPreview extends StatelessWidget {
  const _ServerMetricsPreview({this.server});
  final ServerModel? server;

  @override
  Widget build(BuildContext context) {
    final metricsServer = server;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: DokployTheme.backgroundOf(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: DokployTheme.borderOf(context)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.memory_rounded,
              size: 17, color: DokployTheme.foregroundOf(context)),
          const SizedBox(width: 8),
          Text('DPLOYGO  •  SERVER METRICS',
              style: TextStyle(
                color: DokployTheme.mutedOf(context),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: .8,
              )),
        ]),
        const SizedBox(height: 10),
        Text(metricsServer?.name ?? 'Monitoring data unavailable',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: DokployTheme.foregroundOf(context),
                fontSize: 15,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        Row(children: [
          _ServerMetric(label: 'CPU', value: metricsServer?.cpu),
          _ServerMetric(label: 'DISK', value: metricsServer?.disk),
        ]),
        if (metricsServer != null && metricsServer.diskTotalGb > 0) ...[
          const SizedBox(height: 8),
          Text(
            '${metricsServer.diskUsedGb.toStringAsFixed(1)} GB used of ${metricsServer.diskTotalGb.toStringAsFixed(1)} GB',
            style:
                TextStyle(color: DokployTheme.mutedOf(context), fontSize: 11),
          ),
        ],
      ]),
    );
  }
}

class _ServerMetric extends StatelessWidget {
  const _ServerMetric({required this.label, required this.value});
  final String label;
  final double? value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value == null ? '—' : '${value!.toStringAsFixed(0)}%',
              style: TextStyle(
                  color: DokployTheme.foregroundOf(context),
                  fontSize: 24,
                  fontWeight: FontWeight.w800)),
          Text(label,
              style: TextStyle(
                  color: DokployTheme.mutedOf(context),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .5)),
        ]),
      );
}

class _CombinedWidgetPreview extends StatelessWidget {
  const _CombinedWidgetPreview({
    required this.data,
    required this.instanceName,
    required this.server,
  });

  final DashboardSnapshot data;
  final String instanceName;
  final ServerModel? server;

  @override
  Widget build(BuildContext context) {
    final metricsServer = server;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: DokployTheme.backgroundOf(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: DokployTheme.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dashboard_rounded,
                  size: 17, color: DokployTheme.foregroundOf(context)),
              const SizedBox(width: 8),
              Text(
                'DPLOYGO  •  ALL-IN-ONE',
                style: TextStyle(
                  color: DokployTheme.mutedOf(context),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            instanceName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: DokployTheme.foregroundOf(context),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _WidgetMetric('RUN', data.running, DokployTheme.success),
              _WidgetMetric('STOP', data.stopped, DokployTheme.warning),
              _WidgetMetric('FAIL', data.failed, DokployTheme.danger),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              _ServerMetric(label: 'CPU', value: metricsServer?.cpu),
              _ServerMetric(label: 'DISK', value: metricsServer?.disk),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            metricsServer == null
                ? 'Server monitoring data unavailable'
                : '${metricsServer.name} · ${metricsServer.diskUsedGb.toStringAsFixed(1)} / ${metricsServer.diskTotalGb.toStringAsFixed(1)} GB disk',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: DokployTheme.mutedOf(context),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
