import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers.dart';
import '../core/widgets.dart';
import '../domain/models.dart';

class DatabasesScreen extends ConsumerWidget {
  const DatabasesScreen({super.key});

  static const _databaseKinds = {
    ServiceKind.postgres,
    ServiceKind.mysql,
    ServiceKind.mariadb,
    ServiceKind.mongo,
    ServiceKind.redis,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(servicesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Databases')),
      body: services.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load databases: $error'),
          ),
        ),
        data: (items) {
          final databases = items
              .where((service) => _databaseKinds.contains(service.kind))
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));
          if (databases.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.storage_outlined, size: 38),
                    SizedBox(height: 12),
                    Text('No database services found.'),
                  ],
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
            children: [
              Text(
                '${databases.length} database service${databases.length == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 12),
              ...databases.map(
                (database) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: ListTile(
                      onTap: () => context.push('/service/${database.id}'),
                      leading: CircleAvatar(
                        child: Icon(_icon(database.kind), size: 20),
                      ),
                      title: Text(
                        database.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${_label(database.kind)} • ${database.project}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          StatusDot(database.status),
                          const SizedBox(width: 12),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static IconData _icon(ServiceKind kind) => switch (kind) {
        ServiceKind.postgres => Icons.storage,
        ServiceKind.mysql || ServiceKind.mariadb => Icons.table_chart_outlined,
        ServiceKind.mongo => Icons.circle_outlined,
        ServiceKind.redis => Icons.bolt_outlined,
        _ => Icons.storage_outlined,
      };

  static String _label(ServiceKind kind) => switch (kind) {
        ServiceKind.postgres => 'PostgreSQL',
        ServiceKind.mysql => 'MySQL',
        ServiceKind.mariadb => 'MariaDB',
        ServiceKind.mongo => 'MongoDB',
        ServiceKind.redis => 'Redis',
        _ => kind.name,
      };
}
