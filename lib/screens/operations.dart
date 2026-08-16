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
    final demo = ref.watch(currentInstanceProvider).demo;
    return Scaffold(
        appBar: AppBar(title: const Text('Operations')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          _hero(c),
          const SectionTitle('Infrastructure'),
          _nav(
              Icons.backup_outlined,
              'Backups',
              'Database, volume and control-plane backups',
              demo ? () => _showBackups(c, ref) : null,
              upcoming: !demo),
          _nav(
              Icons.schedule,
              'Scheduled jobs',
              'Cron jobs, run history and logs',
              demo ? () => _showSchedules(c, ref) : null,
              upcoming: !demo),
          _nav(Icons.language, 'Domains', 'Routes, HTTPS and target ports',
              demo ? () => _showDomains(c, ref) : null,
              upcoming: !demo),
          _nav(Icons.storage, 'Databases',
              'Postgres, MySQL, MariaDB, Mongo and Redis lifecycle', null,
              upcoming: true),
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
          _nav(Icons.widgets_outlined, 'Widgets & shortcuts',
              'Home-screen health and quick actions', null,
              upcoming: true),
        ]));
  }

  Widget _hero(BuildContext c) => Card(
      child: Padding(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.grid_view_rounded, color: DokployTheme.primary),
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
    final x = ref.read(backupsProvider);
    _sheet(
        c,
        'Backups',
        x.valueOrNull
                ?.map((b) => ListTile(
                    leading: StatusDot(b.status),
                    title: Text(b.name),
                    subtitle:
                        Text('${b.target} • ${b.sizeMb.toStringAsFixed(0)} MB'),
                    trailing: IconButton(
                        onPressed: () {}, icon: const Icon(Icons.play_arrow))))
                .toList() ??
            []);
  }

  void _showSchedules(BuildContext c, WidgetRef ref) {
    final x = ref.read(schedulesProvider);
    _sheet(
        c,
        'Scheduled jobs',
        x.valueOrNull
                ?.map((j) => ListTile(
                    leading: StatusDot(j.lastStatus),
                    title: Text(j.name),
                    subtitle: Text(j.cron),
                    trailing: IconButton(
                        onPressed: () {}, icon: const Icon(Icons.play_arrow))))
                .toList() ??
            []);
  }

  void _showDomains(BuildContext c, WidgetRef ref) {
    final x = ref.read(domainsProvider);
    _sheet(
        c,
        'Domains',
        x.valueOrNull
                ?.map((d) => ListTile(
                    leading: Icon(d.https ? Icons.lock : Icons.language),
                    title: Text(d.host),
                    subtitle: Text('${d.target} • :${d.port}')))
                .toList() ??
            []);
  }

  void _sheet(BuildContext c, String title, List<Widget> items) {
    showModalBottomSheet(
        context: c,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (c) => FractionallySizedBox(
            heightFactor: .72,
            child: Scaffold(
                appBar: AppBar(
                    title: Text(title), automaticallyImplyLeading: false),
                body: ListView(
                    padding: const EdgeInsets.all(12), children: items))));
  }
}
