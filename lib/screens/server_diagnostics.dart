import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart';
import '../core/widgets.dart';
import '../domain/models.dart';

final serverDiagnosticsProvider = FutureProvider.autoDispose
    .family<ServerDiagnostics, String?>((ref, id) =>
        ref.watch(repositoryProvider).serverDiagnostics(serverId: id));

class ServerDiagnosticsScreen extends ConsumerWidget {
  const ServerDiagnosticsScreen({super.key, required this.server});
  final ServerModel server;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = server.id == 'dokploy-control-plane' ? null : server.id;
    String count(num? value) => value?.toString() ?? 'Unavailable';
    String storage(num? used, num? total) => used == null ||
            total == null ||
            total <= 0
        ? 'Unavailable'
        : '${(used / 1073741824).toStringAsFixed(1)} / ${(total / 1073741824).toStringAsFixed(1)} GiB';
    return Scaffold(
        appBar: AppBar(title: const Text('Server diagnostics'), actions: [
          IconButton(
              tooltip: 'Refresh diagnostics',
              onPressed: () => ref.invalidate(serverDiagnosticsProvider(id)),
              icon: const Icon(Icons.refresh)),
        ]),
        body: ref.watch(serverDiagnosticsProvider(id)).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.monitor_heart_outlined, size: 40),
                        const SizedBox(height: 16),
                        Text('Diagnostics unavailable\n$error',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        const Text(
                            'Requires a Dokploy version with server health support and Docker/server read permissions.',
                            textAlign: TextAlign.center),
                        TextButton(
                            onPressed: () =>
                                ref.invalidate(serverDiagnosticsProvider(id)),
                            child: const Text('Retry')),
                      ]))),
              data: (data) =>
                  ListView(padding: const EdgeInsets.all(16), children: [
                Text(server.name,
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                const Text('Host resource snapshot reported by Dokploy'),
                const SizedBox(height: 20),
                GlassPanel(
                    child: Column(children: [
                  for (final entry in {
                    'CPU cores': count(data.cpuCount),
                    'Containers': count(data.containers),
                    'Swarm services': count(data.services),
                    'Docker networks': count(data.networks),
                    'Memory used / total':
                        storage(data.memoryUsed, data.memoryTotal),
                    'Disk used / total': storage(data.diskUsed, data.diskTotal),
                  }.entries)
                    ListTile(
                        title: Text(entry.key),
                        subtitle: Text(entry.value,
                            style: Theme.of(context).textTheme.titleLarge)),
                ])),
              ]),
            ));
  }
}
