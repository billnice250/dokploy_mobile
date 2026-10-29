import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/providers.dart';
import '../core/widgets.dart';
import '../core/theme.dart';

class OperationsScreen extends ConsumerWidget {
  const OperationsScreen({super.key});
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    ref.watch(currentInstanceProvider);
    final capabilities = ref.watch(capabilitiesProvider).valueOrNull;
    return Scaffold(
        appBar: AppBar(title: const Text('Operations')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          _hero(c),
          const SectionTitle('Infrastructure'),
          _nav(
              Icons.backup_outlined,
              'Backups',
              'Database, volume and control-plane backups',
              capabilities?.backups == true ? () => _showBackups(c, ref) : null,
              upcoming: capabilities?.backups != true),
          _nav(
              Icons.schedule,
              'Scheduled jobs',
              'Cron jobs, run history and logs',
              capabilities?.schedules == true
                  ? () => _showSchedules(c, ref)
                  : null,
              upcoming: capabilities?.schedules != true),
          _nav(Icons.language, 'Domains', 'Routes, HTTPS and target ports',
              capabilities?.domains == true ? () => _showDomains(c, ref) : null,
              upcoming: capabilities?.domains != true),
          _nav(
            Icons.storage,
            'Databases',
            'PostgreSQL, MySQL, MariaDB, MongoDB and Redis',
            capabilities?.databases == true ? () => c.push('/databases') : null,
            upcoming: capabilities?.databases != true,
          ),
          _nav(
              Icons.swap_vert_rounded,
              'Traefik requests',
              'Live access log with HTTP status filters',
              () => c.push('/traefik-requests')),
          const SectionTitle('Power tools'),
          _nav(Icons.terminal, 'Terminal',
              'Application / Compose / database shell (capability gated)', null,
              upcoming: true),
          _nav(
              Icons.notifications_active_outlined,
              'Notifications',
              'Deployment changes and local notification history',
              () => c.push('/notifications')),
          _nav(
              Icons.widgets_outlined,
              'Home-screen widget',
              'Infrastructure health on your home screen',
              () => c.push('/widgets')),
        ]));
  }

  Widget _hero(BuildContext c) => Card(
      child: Padding(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.grid_view_rounded,
                color: Theme.of(c).colorScheme.primary),
            const SizedBox(height: 14),
            Text('Command Center',
                style: Theme.of(c)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text(
                'Fast access to operational workflows designed for a phone.',
                style: TextStyle(color: DokployTheme.muted))
          ])));
  Widget _nav(IconData i, String t, String s, VoidCallback? onTap,
          {bool upcoming = false}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Card(
              child: ListTile(
                  onTap: onTap,
                  leading: Icon(i),
                  title: Text(t),
                  subtitle: Text(s),
                  trailing: upcoming
                      ? const UpcomingBadge()
                      : const Icon(Icons.chevron_right))));
  void _showBackups(BuildContext c, WidgetRef ref) {
    _sheet(c, 'Backups', Consumer(builder: (context, ref, _) {
      final state = ref.watch(backupsProvider);
      return state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Could not load backups: $error')),
        data: (backups) => backups.isEmpty
            ? const Center(child: Text('No backups found.'))
            : ListView(
                children: backups
                    .map((backup) => ListTile(
                          leading: StatusDot(backup.status),
                          title: Text(backup.name),
                          subtitle: Text(
                              '${backup.target} • ${backup.sizeMb.toStringAsFixed(0)} MB'),
                        ))
                    .toList()),
      );
    }));
  }

  void _showSchedules(BuildContext c, WidgetRef ref) {
    _sheet(c, 'Scheduled jobs', Consumer(builder: (context, ref, _) {
      final state = ref.watch(schedulesProvider);
      return state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Could not load schedules: $error')),
        data: (jobs) => jobs.isEmpty
            ? const Center(child: Text('No scheduled jobs found.'))
            : ListView(
                children: jobs
                    .map((job) => ListTile(
                          leading: StatusDot(job.lastStatus),
                          title: Text(job.name),
                          subtitle: Text(job.cron),
                        ))
                    .toList()),
      );
    }));
  }

  void _showDomains(BuildContext c, WidgetRef ref) {
    _sheet(c, 'Domains', Consumer(builder: (context, ref, _) {
      final state = ref.watch(domainsProvider);
      return state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Could not load domains: $error')),
        data: (domains) => domains.isEmpty
            ? const Center(child: Text('No domains found.'))
            : ListView(
                children: domains
                    .map((domain) => ListTile(
                          leading:
                              Icon(domain.https ? Icons.lock : Icons.language),
                          title: Text(domain.host),
                          subtitle: Text('${domain.target} • :${domain.port}'),
                        ))
                    .toList()),
      );
    }));
  }

  void _sheet(BuildContext c, String title, Widget body) {
    showModalBottomSheet(
        context: c,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (c) => FractionallySizedBox(
            heightFactor: .72,
            child: Scaffold(
                appBar: AppBar(
                    title: Text(title), automaticallyImplyLeading: false),
                body:
                    Padding(padding: const EdgeInsets.all(12), child: body))));
  }
}
