import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/biometric_confirmation.dart';
import '../core/providers.dart';
import '../core/widgets.dart';
import '../domain/models.dart';

final serverSecurityProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, id) => ref.read(repositoryProvider).serverSecurity(id),
);

class ServerSecurityScreen extends ConsumerStatefulWidget {
  const ServerSecurityScreen({super.key, required this.server});
  final ServerModel server;

  @override
  ConsumerState<ServerSecurityScreen> createState() =>
      _ServerSecurityScreenState();
}

class _ServerSecurityScreenState extends ConsumerState<ServerSecurityScreen> {
  bool? _authorized;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _authorize());
  }

  Future<void> _authorize() async {
    final allowed = ref.read(currentInstanceProvider).demo ||
        await confirmSensitiveOperation(
          context,
          ref,
          reason:
              'View security status for server ${widget.server.name}, including recent activity.',
        );
    if (mounted) setState(() => _authorized = allowed);
  }

  @override
  Widget build(BuildContext context) {
    final server = widget.server;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Server security'),
        actions: [
          IconButton(
            tooltip: 'Refresh security status',
            onPressed: () => ref.invalidate(serverSecurityProvider(server.id)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _authorized == null
          ? const Center(child: CircularProgressIndicator())
          : _authorized == false
              ? const Center(
                  child: Text('Viewing server security was cancelled.'))
              : _securityState(context, ref),
    );
  }

  Widget _securityState(BuildContext context, WidgetRef ref) =>
      ref.watch(serverSecurityProvider(widget.server.id)).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.security_outlined, size: 40),
                    const SizedBox(height: 12),
                    const Text('Security status unavailable',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text('$error', textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    const Text(
                      'Dokploy v0.31 server.security is read-only here. Changes to SSH, firewall and IP bans remain in Dokploy.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            data: (data) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(widget.server.name,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(widget.server.host,
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 16),
                GlassPanel(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Security snapshot',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      for (final entry in _flatten(data).entries)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(entry.key),
                          subtitle: SelectableText(entry.value),
                        ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Read-only snapshot. Manage firewall, SSH, Fail2ban, IP bans and sessions in Dokploy.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );

  Map<String, String> _flatten(Map<String, dynamic> raw) {
    final result = <String, String>{};
    void visit(String prefix, dynamic value) {
      if (value is Map) {
        for (final entry in value.entries) {
          visit(prefix.isEmpty ? '${entry.key}' : '$prefix · ${entry.key}',
              entry.value);
        }
      } else if (value is List) {
        result[prefix] = value.map((item) => '$item').join(', ');
      } else if (value != null) {
        result[prefix] = '$value';
      }
    }

    visit('', raw);
    return result;
  }
}
