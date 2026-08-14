import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/providers.dart';
import '../core/widgets.dart';
import '../core/theme.dart';
import '../domain/models.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dash = ref.watch(dashboardProvider);
    final inst = ref.watch(currentInstanceProvider);
    final capabilities = ref.watch(capabilitiesProvider).valueOrNull;
    return Scaffold(
        appBar: AppBar(
            title: Row(children: [
              Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                      color: DokployTheme.purple,
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.hexagon_outlined, size: 18)),
              const SizedBox(width: 10),
              const Text('Dokploy')
            ]),
            actions: [
              IconButton(
                  onPressed: () => context.push('/operations'),
                  icon: const Icon(Icons.apps)),
              IconButton(
                  onPressed: () => context.push('/settings'),
                  icon: const Icon(Icons.settings_outlined))
            ]),
        body: RefreshIndicator(
            onRefresh: () async => ref.invalidate(dashboardProvider),
            child: dash.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => ListView(children: [
                      Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('Could not load dashboard: $e'))
                    ]),
                data: (d) => ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                        children: [
                          Row(children: [
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(inst.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  Row(children: [
                                    const StatusDot(HealthState.healthy),
                                    const SizedBox(width: 7),
                                    Text(
                                        inst.demo
                                            ? 'Demo mode'
                                            : 'Connected • Dokploy ${inst.version}',
                                        style: const TextStyle(
                                            color: DokployTheme.muted))
                                  ])
                                ])),
                            IconButton.filledTonal(
                                onPressed: () =>
                                    ref.invalidate(dashboardProvider),
                                icon: const Icon(Icons.refresh))
                          ]),
                          const SizedBox(height: 18),
                          SizedBox(
                              height: 116,
                              child: Row(children: [
                                Expanded(
                                    child: MetricCard(
                                        label: 'Running',
                                        value: '${d.running}',
                                        icon: Icons.play_circle_outline,
                                        accent: DokployTheme.success)),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: MetricCard(
                                        label: 'Stopped',
                                        value: '${d.stopped}',
                                        icon: Icons.stop_circle_outlined)),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: MetricCard(
                                        label: 'Failed',
                                        value: '${d.failed}',
                                        icon: Icons.error_outline,
                                        accent: DokployTheme.danger))
                              ])),
                          const SectionTitle('Recent deployments'),
                          if (capabilities?.deployments == false)
                            const _UnavailableCard(
                                'Deployment history is unavailable for this token.')
                          else
                            ...d.deployments.map((x) => _DeploymentTile(x)),
                          const SectionTitle('Attention'),
                          ...d.attention.map((x) => Card(
                              child: ListTile(
                                  leading: const Icon(
                                      Icons.warning_amber_rounded,
                                      color: DokployTheme.warning),
                                  title: Text(x),
                                  trailing: const Icon(Icons.chevron_right)))),
                          if (capabilities?.servers != false) ...[
                            const SectionTitle('Servers'),
                            ...d.servers.take(3).map((s) => Card(
                                child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(children: [
                                      Row(children: [
                                        StatusDot(s.status),
                                        const SizedBox(width: 9),
                                        Expanded(
                                            child: Text(s.name,
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w600))),
                                        Text(s.host,
                                            style: const TextStyle(
                                                color: DokployTheme.muted,
                                                fontSize: 12))
                                      ]),
                                      const SizedBox(height: 16),
                                      ProgressMetric(
                                          label: 'Disk', value: s.disk)
                                    ])))),
                          ],
                        ]))));
  }
}

class _UnavailableCard extends StatelessWidget {
  const _UnavailableCard(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Card(
      child: ListTile(
          leading: const Icon(Icons.lock_outline, color: DokployTheme.muted),
          title: Text(message)));
}

class _DeploymentTile extends StatelessWidget {
  const _DeploymentTile(this.d);
  final DeploymentModel d;
  @override
  Widget build(BuildContext c) => Card(
      child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: StatusDot(d.status, size: 10),
          title: Text(d.service,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
              '${d.branch}${d.commit.isEmpty ? '' : ' • ${d.commit}'}\n${d.message}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          isThreeLine: true,
          trailing: d.status == HealthState.deploying
              ? SizedBox(
                  width: 42,
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                        const SizedBox(height: 4),
                        Text('${d.durationSeconds}s',
                            style: const TextStyle(
                                fontSize: 10, color: DokployTheme.muted))
                      ]))
              : const Icon(Icons.chevron_right)));
}
