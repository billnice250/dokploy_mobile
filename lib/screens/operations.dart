import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart';
import '../core/widgets.dart';
import '../core/theme.dart';
import '../domain/models.dart';

class OperationsScreen extends ConsumerWidget {
  const OperationsScreen({super.key});
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final capabilities =
        ref.watch(capabilitiesProvider).valueOrNull ?? const CapabilitySet();
    return Scaffold(
        appBar: AppBar(title: const Text('Operations')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          _hero(c),
          const SectionTitle('Infrastructure'),
          _nav(
              Icons.backup_outlined,
              'Backups',
              'Database, volume and control-plane backups',
              capabilities.backups ? () => _showBackups(c, ref) : null),
          _nav(
              Icons.schedule,
              'Scheduled jobs',
              'Cron jobs, run history and logs',
              capabilities.schedules ? () => _showSchedules(c, ref) : null),
          _nav(Icons.language, 'Domains', 'Routes, HTTPS and target ports',
              capabilities.domains ? () => _showDomains(c, ref) : null),
          _nav(Icons.storage, 'Databases',
              'Postgres, MySQL, MariaDB, Mongo and Redis lifecycle', null),
          const SectionTitle('Power tools'),
          _nav(
              Icons.terminal,
              'Terminal',
              'Application / Compose / database shell (capability gated)',
              capabilities.terminal ? () {} : null),
          _nav(Icons.notifications_active_outlined, 'Notifications',
              'Deployment failures, backup failures and health alerts', null),
          _nav(Icons.widgets_outlined, 'Widgets & shortcuts',
              'Home-screen health and quick actions', null),
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
  Widget _nav(IconData i, String t, String s, VoidCallback? onTap) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
          child: ListTile(
              onTap: onTap,
              leading: Icon(i),
              title: Text(t),
              subtitle: Text(s),
              trailing: const Icon(Icons.chevron_right))));
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
