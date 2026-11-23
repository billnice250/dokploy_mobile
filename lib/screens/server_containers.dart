import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart';
import '../core/biometric_confirmation.dart';
import '../core/widgets.dart';
import '../domain/models.dart';
import '../domain/terminal_session.dart';
import 'terminal.dart';

final serverContainersProvider = FutureProvider.autoDispose
    .family<List<ContainerInstance>, String?>((ref, id) =>
        ref.watch(repositoryProvider).serverContainers(serverId: id));

class ServerContainersScreen extends ConsumerStatefulWidget {
  const ServerContainersScreen({super.key, required this.server});
  final ServerModel server;
  @override
  ConsumerState<ServerContainersScreen> createState() =>
      _ServerContainersScreenState();
}

class _ServerContainersScreenState
    extends ConsumerState<ServerContainersScreen> {
  String _query = '';
  bool _runningOnly = false;
  bool _busy = false;
  String? get _serverId =>
      widget.server.id == 'dokploy-control-plane' ? null : widget.server.id;

  Future<void> _action(
      ContainerInstance container, ContainerAction action) async {
    final repository = ref.read(repositoryProvider);
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(
                    '${action.name[0].toUpperCase()}${action.name.substring(1)} ${container.name}?'),
                content: Text(
                    'This affects the container on ${widget.server.name}. '
                    'Stopping or restarting may interrupt traffic. Managed services may recreate containers automatically.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Confirm'))
                ]));
    if (confirmed != true || !mounted) return;
    final authorized = ref.read(currentInstanceProvider).demo ||
        await confirmSensitiveOperation(context, ref,
            reason: 'Confirm container ${action.name}.');
    if (!authorized || !mounted || repository != ref.read(repositoryProvider)) {
      return;
    }
    setState(() => _busy = true);
    try {
      await repository.containerAction(container.id, action,
          serverId: _serverId);
      ref.invalidate(serverContainersProvider(_serverId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Container ${action.name} requested.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Operation failed: $error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventory = ref.watch(serverContainersProvider(_serverId));
    return Scaffold(
      appBar: AppBar(title: Text(widget.server.name), actions: [
        IconButton(
            tooltip: 'Refresh containers',
            onPressed: () =>
                ref.invalidate(serverContainersProvider(_serverId)),
            icon: const Icon(Icons.refresh)),
      ]),
      body: SafeArea(
          child: Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Containers',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Inspect workloads and manage their runtime.',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 20),
              TextField(
                  onChanged: (value) =>
                      setState(() => _query = value.toLowerCase()),
                  decoration: const InputDecoration(
                      hintText: 'Search name, image or ID',
                      prefixIcon: Icon(Icons.search))),
              const SizedBox(height: 10),
              Wrap(spacing: 8, children: [
                FilterChip(
                    label: const Text('Running only'),
                    selected: _runningOnly,
                    onSelected: (value) =>
                        setState(() => _runningOnly = value)),
                if (inventory.hasValue)
                  Chip(label: Text('${inventory.value!.length} containers')),
              ]),
            ])),
        if (_busy) const LinearProgressIndicator(),
        Expanded(
            child: inventory.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.cloud_off_outlined, size: 40),
                    const SizedBox(height: 12),
                    Text('Container inventory unavailable\n$error',
                        textAlign: TextAlign.center),
                    TextButton(
                        onPressed: () =>
                            ref.invalidate(serverContainersProvider(_serverId)),
                        child: const Text('Retry')),
                  ]))),
          data: (items) {
            final filtered = items
                .where((item) =>
                    (!_runningOnly || item.running) &&
                    '${item.name} ${item.image} ${item.id}'
                        .toLowerCase()
                        .contains(_query))
                .toList();
            return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(serverContainersProvider(_serverId));
                  await ref.read(serverContainersProvider(_serverId).future);
                },
                child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      if (filtered.isEmpty)
                        const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(
                                child: Text('No containers match this view.'))),
                      for (final item in filtered)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: GlassPanel(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Icon(Icons.inventory_2_outlined,
                                            color: item.running
                                                ? Colors.green
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant),
                                        const SizedBox(width: 12),
                                        Expanded(
                                            child: Text(item.name,
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 17))),
                                        const SizedBox(width: 8),
                                        Text(item.state)
                                      ]),
                                      const SizedBox(height: 12),
                                      SelectableText(
                                          item.image.isEmpty
                                              ? item.id
                                              : item.image,
                                          style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant)),
                                      if (item.status.isNotEmpty)
                                        Padding(
                                            padding:
                                                const EdgeInsets.only(top: 6),
                                            child: Text(item.status)),
                                      if (item.ports.isNotEmpty)
                                        Padding(
                                            padding:
                                                const EdgeInsets.only(top: 6),
                                            child: Text(item.ports)),
                                      const SizedBox(height: 12),
                                      Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            OutlinedButton.icon(
                                                onPressed: _busy
                                                    ? null
                                                    : () => _action(
                                                        item,
                                                        item.running
                                                            ? ContainerAction
                                                                .stop
                                                            : ContainerAction
                                                                .start),
                                                icon: Icon(item.running
                                                    ? Icons.stop
                                                    : Icons.play_arrow),
                                                label: Text(item.running
                                                    ? 'Stop'
                                                    : 'Start')),
                                            if (item.running)
                                              OutlinedButton.icon(
                                                  onPressed: _busy
                                                      ? null
                                                      : () => _action(
                                                          item,
                                                          ContainerAction
                                                              .restart),
                                                  icon: const Icon(
                                                      Icons.restart_alt),
                                                  label: const Text('Restart')),
                                            if (item.running)
                                              FilledButton.tonalIcon(
                                                  onPressed: _busy
                                                      ? null
                                                      : () => Navigator.of(
                                                              context,
                                                              rootNavigator:
                                                                  true)
                                                          .push(MaterialPageRoute<
                                                                  void>(
                                                              builder: (_) => TerminalScreen(
                                                                  title:
                                                                      item.name,
                                                                  serverId:
                                                                      _serverId,
                                                                  containerId:
                                                                      item.id))),
                                                  icon: const Icon(Icons.terminal),
                                                  label: const Text('Shell')),
                                          ]),
                                    ]))),
                    ]));
          },
        )),
      ])),
    );
  }
}
