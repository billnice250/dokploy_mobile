import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/providers.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../domain/models.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);
    final instance = ref.watch(currentInstanceProvider);
    final capabilities = ref.watch(capabilitiesProvider).valueOrNull;
    final notifications =
        ref.watch(notificationHistoryProvider(instance.id)).valueOrNull;
    final unread = notifications?.where((item) => !item.read).length ?? 0;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: DokployTheme.bg.withValues(alpha: .72),
        title: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: DokployTheme.primary,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: .12),
                    blurRadius: 18,
                  ),
                ],
              ),
              child: const Icon(
                Icons.hexagon_outlined,
                size: 18,
                color: DokployTheme.onPrimary,
              ),
            ),
            const SizedBox(width: 10),
            const Text('Dokploy'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => context.push('/notifications'),
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text(unread > 99 ? '99+' : '$unread'),
              child: const Icon(Icons.notifications_none_rounded),
            ),
          ),
          IconButton(
            tooltip: 'Operations',
            onPressed: () => context.push('/operations'),
            icon: const Icon(Icons.grid_view_rounded),
          ),
          IconButton(
            tooltip: 'Instances and settings',
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: Stack(
        children: [
          const _AmbientBackground(),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(dashboardProvider);
                ref.invalidate(serversProvider);
                ref.invalidate(deploymentsProvider);
                await ref.read(dashboardProvider.future);
              },
              child: dashboard.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (error, _) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  children: [
                    const SizedBox(height: 80),
                    const Icon(Icons.cloud_off_outlined, size: 38),
                    const SizedBox(height: 14),
                    Text(
                      'Could not load the command center',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: DokployTheme.muted),
                    ),
                  ],
                ),
                data: (snapshot) => _DashboardContent(
                  snapshot: snapshot,
                  instance: instance,
                  capabilities: capabilities,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.snapshot,
    required this.instance,
    required this.capabilities,
  });

  final DashboardSnapshot snapshot;
  final DokployInstance instance;
  final CapabilitySet? capabilities;

  @override
  Widget build(BuildContext context) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
        children: [
          _HealthHero(snapshot: snapshot, instance: instance),
          const SizedBox(height: 14),
          _StatusStrip(snapshot),
          const SectionTitle('Quick actions'),
          const _QuickActions(),
          SectionTitle(
            'Recent deployments',
            trailing: TextButton(
              onPressed: () => context.go('/activity'),
              child: const Text('View all'),
            ),
          ),
          if (capabilities?.deployments == false)
            const _UnavailableCard(
              'Deployment history is unavailable for this token.',
            )
          else if (snapshot.deployments.isEmpty)
            const _EmptyPanel(
              icon: Icons.rocket_launch_outlined,
              label: 'No recent deployments',
            )
          else
            ...snapshot.deployments.map(
              (deployment) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DeploymentTile(deployment),
              ),
            ),
          if (snapshot.attention.isNotEmpty) ...[
            const SectionTitle('Needs attention'),
            GlassPanel(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var index = 0;
                      index < snapshot.attention.length;
                      index++) ...[
                    ListTile(
                      leading: const Icon(
                        Icons.warning_amber_rounded,
                        color: DokployTheme.warning,
                      ),
                      title: Text(snapshot.attention[index]),
                    ),
                    if (index < snapshot.attention.length - 1)
                      const Divider(height: 1),
                  ],
                ],
              ),
            ),
          ],
          if (capabilities?.servers != false) ...[
            SectionTitle(
              'Infrastructure',
              trailing: TextButton(
                onPressed: () => context.go('/servers'),
                child: const Text('All servers'),
              ),
            ),
            if (snapshot.servers.isEmpty)
              const _EmptyPanel(
                icon: Icons.monitor_heart_outlined,
                label: 'No server inventory returned',
              )
            else
              ...snapshot.servers.take(3).map(
                    (server) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ServerCard(server),
                    ),
                  ),
          ],
        ],
      );
}

class _HealthHero extends StatelessWidget {
  const _HealthHero({required this.snapshot, required this.instance});

  final DashboardSnapshot snapshot;
  final DokployInstance instance;

  @override
  Widget build(BuildContext context) {
    final healthy = snapshot.failed == 0 && snapshot.attention.isEmpty;
    final greeting = switch (DateTime.now().hour) {
      < 12 => 'Good morning',
      < 18 => 'Good afternoon',
      _ => 'Good evening',
    };
    return GlassPanel(
      padding: const EdgeInsets.all(20),
      onTap: () => context.push('/settings'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            greeting,
            style: const TextStyle(color: DokployTheme.muted),
          ),
          const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      healthy
                          ? 'Everything looks good'
                          : '${snapshot.attention.length + snapshot.failed} item(s) need attention',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -.5,
                              ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        StatusDot(
                          healthy ? HealthState.healthy : HealthState.warning,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '${instance.name}  •  ${instance.demo ? 'Demo' : 'Connected'}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: DokployTheme.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (healthy ? DokployTheme.success : DokployTheme.warning)
                      .withValues(alpha: .1),
                  border: Border.all(
                    color:
                        (healthy ? DokployTheme.success : DokployTheme.warning)
                            .withValues(alpha: .3),
                  ),
                ),
                child: Icon(
                  healthy ? Icons.check_rounded : Icons.priority_high_rounded,
                  color: healthy ? DokployTheme.success : DokployTheme.warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip(this.snapshot);

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) => GlassPanel(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            _StatusValue(
              value: snapshot.running,
              label: 'Running',
              color: DokployTheme.success,
            ),
            const _VerticalDivider(),
            _StatusValue(
              value: snapshot.stopped,
              label: 'Stopped',
              color: DokployTheme.muted,
            ),
            const _VerticalDivider(),
            _StatusValue(
              value: snapshot.failed,
              label: 'Failed',
              color: DokployTheme.danger,
            ),
          ],
        ),
      );
}

class _StatusValue extends StatelessWidget {
  const _StatusValue({
    required this.value,
    required this.label,
    required this.color,
  });

  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text(
              '$value',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
            ),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: DokployTheme.muted)),
          ],
        ),
      );
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 34,
        child: VerticalDivider(width: 1),
      );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 88,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _QuickAction(
              icon: Icons.rocket_launch_outlined,
              label: 'Deployments',
              onTap: () => context.go('/activity'),
            ),
            _QuickAction(
              icon: Icons.subject,
              label: 'Logs',
              onTap: () => context.go('/projects'),
            ),
            _QuickAction(
              icon: Icons.dns_outlined,
              label: 'Servers',
              onTap: () => context.go('/servers'),
            ),
            _QuickAction(
              icon: Icons.grid_view_rounded,
              label: 'Operations',
              onTap: () => context.push('/operations'),
            ),
          ],
        ),
      );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 10),
        child: SizedBox(
          width: 108,
          child: GlassPanel(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, size: 20),
                Text(
                  label,
                  maxLines: 1,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      );
}

class _DeploymentTile extends StatelessWidget {
  const _DeploymentTile(this.deployment);

  final DeploymentModel deployment;

  @override
  Widget build(BuildContext context) => GlassPanel(
        padding: EdgeInsets.zero,
        onTap: () => context.push('/deployment/${deployment.id}'),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: StatusDot(deployment.status, size: 10),
          title: Text(
            deployment.service,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            [
              if (deployment.branch.isNotEmpty) deployment.branch,
              if (deployment.commit.isNotEmpty) deployment.commit,
              _relativeTime(deployment.createdAt),
            ].join('  •  '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: deployment.status == HealthState.deploying
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.chevron_right),
        ),
      );

  static String _relativeTime(DateTime value) {
    final difference = DateTime.now().difference(value);
    if (difference.inMinutes < 1) return 'now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    return DateFormat('d MMM').format(value);
  }
}

class _ServerCard extends StatelessWidget {
  const _ServerCard(this.server);

  final ServerModel server;

  @override
  Widget build(BuildContext context) => GlassPanel(
        onTap: () => context.go('/servers'),
        child: Column(
          children: [
            Row(
              children: [
                StatusDot(server.status),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        server.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        server.host,
                        style: const TextStyle(
                          color: DokployTheme.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (server.metricsAvailable)
                  Text(
                    _uptime(server.uptimeSeconds),
                    style: const TextStyle(
                      color: DokployTheme.muted,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (!server.metricsAvailable)
              const Row(
                children: [
                  Icon(
                    Icons.monitor_heart_outlined,
                    size: 18,
                    color: DokployTheme.muted,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Monitoring is not configured or has no data yet',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: DokployTheme.muted),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  _MiniMetric('CPU', server.cpu),
                  const SizedBox(width: 8),
                  _MiniMetric('RAM', server.memory),
                  const SizedBox(width: 8),
                  _MiniMetric('Disk', server.disk),
                ],
              ),
          ],
        ),
      );

  static String _uptime(int seconds) {
    if (seconds <= 0) return '';
    final days = seconds ~/ Duration.secondsPerDay;
    final hours = (seconds % Duration.secondsPerDay) ~/ Duration.secondsPerHour;
    return days > 0 ? '${days}d ${hours}h uptime' : '${hours}h uptime';
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric(this.label, this.value);

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: DokployTheme.elevated.withValues(alpha: .68),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: DokployTheme.muted,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${value.toStringAsFixed(0)}%',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      );
}

class _UnavailableCard extends StatelessWidget {
  const _UnavailableCard(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => GlassPanel(
        child: Row(
          children: [
            const Icon(Icons.lock_outline, color: DokployTheme.muted),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      );
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => GlassPanel(
        child: Row(
          children: [
            Icon(icon, color: DokployTheme.muted),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(color: DokployTheme.muted)),
          ],
        ),
      );
}

class _AmbientBackground extends StatelessWidget {
  const _AmbientBackground();

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              top: 70,
              right: -90,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: .055),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 430,
              left: -120,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      DokployTheme.info.withValues(alpha: .035),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}
