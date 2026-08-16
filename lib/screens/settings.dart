import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/providers.dart';
import '../core/app_notice.dart';
import '../core/biometric_confirmation.dart';
import '../core/theme.dart';
import '../data/dokploy_api.dart';
import '../data/mock_repository.dart';
import '../data/real_repository.dart';
import '../domain/models.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static final _blogUri = Uri.parse('https://blog.billnice.it/');
  static final _repositoryUri =
      Uri.parse('https://github.com/billnice250/dokploy_mobile');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentInstanceProvider);
    final instances = ref.watch(instancesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Dokploy instances',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(
                onPressed: () => _useDemo(ref),
                icon: const Icon(Icons.science_outlined),
                label: const Text('Demo'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (current.demo) _instanceTile(current, selected: true),
          ...instances.when(
            loading: () => const [LinearProgressIndicator()],
            error: (error, _) =>
                [Text('Could not load saved instances: $error')],
            data: (items) => items
                .map(
                  (instance) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _instanceTile(
                      instance,
                      selected: current.id == instance.id,
                      onTap: () => _switchInstance(context, ref, instance),
                      onRemove: () => _removeInstance(context, ref, instance),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () => _add(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Add Dokploy instance'),
          ),
          const SizedBox(height: 26),
          const Text(
            'Notifications',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              onTap: () => context.push('/notification-settings'),
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('Deployment alerts'),
              subtitle: const Text(
                  'Polling, quiet hours, event rules and push readiness'),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
          ),
          const SizedBox(height: 26),
          const Text(
            'Security',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          const Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.https_outlined),
                  title: Text('HTTPS required'),
                  subtitle: Text(
                      'Invalid TLS certificates are never accepted globally.'),
                ),
                ListTile(
                  leading: Icon(Icons.key),
                  title: Text('API keys'),
                  subtitle: Text('Stored only in Keychain / Android Keystore'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          const Text(
            'Compatibility',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.api_outlined),
                  title: Text('Target Dokploy API'),
                  subtitle: Text(
                    'Dokploy v0.30.0 • capability fallbacks remain enabled for older instances',
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.dns_outlined),
                  title: Text(current.demo
                      ? 'Demo compatibility adapter'
                      : 'Connected API endpoint'),
                  subtitle: Text(current.demo
                      ? 'No remote Dokploy API is used in demo mode.'
                      : _apiEndpoint(current)),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(
                    Icons.info_outline,
                    color: DokployTheme.warning,
                  ),
                  title: Text('Runtime capability detection'),
                  subtitle: Text(
                    'Core access is validated at connection time. Unsupported or permission-limited modules are hidden safely.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          const Text(
            'About DployGo',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  onTap: () => _openLink(context, _blogUri),
                  leading: const Icon(Icons.language_outlined),
                  title: const Text('Bill Nice — Blog & portfolio'),
                  subtitle: const Text('blog.billnice.it'),
                  trailing: const Icon(Icons.open_in_new_rounded),
                ),
                const Divider(height: 1),
                ListTile(
                  onTap: () => _openLink(context, _repositoryUri),
                  leading: const Icon(Icons.code_rounded),
                  title: const Text('Project repository'),
                  subtitle: const Text(
                    'Source code, feature requests and issue reports',
                  ),
                  trailing: const Icon(Icons.open_in_new_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openLink(BuildContext context, Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      DployGoNotice.show(
        context,
        message: 'Could not open ${uri.host}.',
        tone: DployGoNoticeTone.error,
      );
    }
  }

  String _apiEndpoint(DokployInstance instance) {
    var base = instance.baseUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return base.endsWith('/api') ? base : '$base/api';
  }

  Widget _instanceTile(
    DokployInstance instance, {
    required bool selected,
    VoidCallback? onTap,
    VoidCallback? onRemove,
  }) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: instance.demo ? DokployTheme.border : DokployTheme.primary,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
              instance.demo ? Icons.science_outlined : Icons.hexagon_outlined),
        ),
        title: Text(instance.name),
        subtitle: Text(instance.demo ? 'Local demo data' : instance.baseUrl),
        trailing: onRemove == null
            ? Icon(
                selected ? Icons.check_circle : Icons.chevron_right,
                color: selected ? DokployTheme.success : null,
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected)
                    const Icon(Icons.check_circle, color: DokployTheme.success),
                  PopupMenuButton<void>(
                    itemBuilder: (_) => [
                      PopupMenuItem<void>(
                        onTap: onRemove,
                        child: const Row(
                          children: [
                            Icon(Icons.delete_outline,
                                color: DokployTheme.danger),
                            SizedBox(width: 10),
                            Text('Remove'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _switchInstance(
    BuildContext context,
    WidgetRef ref,
    DokployInstance instance,
  ) async {
    final store = ref.read(instanceStoreProvider);
    final apiKey = await store.apiKey(instance.id);
    if (apiKey == null || apiKey.isEmpty) {
      if (context.mounted) {
        DployGoNotice.show(
          context,
          message: 'This instance has no stored API key.',
          tone: DployGoNoticeTone.warning,
        );
      }
      return;
    }
    await store.setActive(instance.id);
    ref.read(currentInstanceProvider.notifier).state = instance;
    ref.read(repositoryProvider.notifier).state = RealDokployRepository(
      DokployApi(baseUrl: instance.baseUrl, apiKey: apiKey),
    );
    _invalidateData(ref);
  }

  Future<void> _removeInstance(
    BuildContext context,
    WidgetRef ref,
    DokployInstance instance,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove ${instance.name}?'),
        content: const Text(
            'The saved profile and its API key will be removed from this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: DokployTheme.danger),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final authorized = await confirmSensitiveOperation(
      context,
      ref,
      reason: 'Confirm removal of ${instance.name} and its saved API key.',
    );
    if (!authorized || !context.mounted) return;
    await ref.read(instanceStoreProvider).remove(instance.id);
    if (ref.read(currentInstanceProvider).id == instance.id) _useDemo(ref);
    ref.invalidate(instancesProvider);
    if (context.mounted) {
      DployGoNotice.show(
        context,
        message: '${instance.name} was removed from this device.',
        tone: DployGoNoticeTone.success,
      );
    }
  }

  void _useDemo(WidgetRef ref) {
    ref.read(currentInstanceProvider.notifier).state = demoInstance;
    ref.read(repositoryProvider.notifier).state = MockDokployRepository();
    _invalidateData(ref);
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final url = TextEditingController();
    final key = TextEditingController();
    final name = TextEditingController(text: 'My Dokploy');
    var busy = false;
    String? error;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setLocalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Add Dokploy instance',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 10),
              TextField(
                controller: url,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'HTTPS URL',
                  hintText: 'https://dokploy.example.com',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: key,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'API key'),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(error!,
                      style: const TextStyle(color: DokployTheme.danger)),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: busy
                    ? null
                    : () async {
                        var normalized = url.text.trim();
                        while (normalized.endsWith('/')) {
                          normalized = normalized.substring(
                            0,
                            normalized.length - 1,
                          );
                        }
                        final uri = Uri.tryParse(normalized);
                        if (uri == null ||
                            uri.scheme != 'https' ||
                            uri.host.isEmpty ||
                            key.text.trim().isEmpty) {
                          setLocalState(
                            () =>
                                error = 'Enter a valid HTTPS URL and API key.',
                          );
                          return;
                        }
                        setLocalState(() {
                          busy = true;
                          error = null;
                        });
                        try {
                          final api = DokployApi(
                            baseUrl: normalized,
                            apiKey: key.text.trim(),
                          );
                          await api.projects();
                          final instance = DokployInstance(
                            id: DateTime.now()
                                .microsecondsSinceEpoch
                                .toString(),
                            name: name.text.trim().isEmpty
                                ? uri.host
                                : name.text.trim(),
                            baseUrl: normalized,
                          );
                          await ref
                              .read(instanceStoreProvider)
                              .save(instance, key.text.trim());
                          ref.read(currentInstanceProvider.notifier).state =
                              instance;
                          ref.read(repositoryProvider.notifier).state =
                              RealDokployRepository(api);
                          ref.invalidate(instancesProvider);
                          _invalidateData(ref);
                          if (sheetContext.mounted) Navigator.pop(sheetContext);
                          if (context.mounted) {
                            DployGoNotice.show(
                              context,
                              message: 'Dokploy instance connected.',
                              tone: DployGoNoticeTone.success,
                            );
                          }
                        } catch (failure) {
                          setLocalState(() {
                            busy = false;
                            error = 'Connection failed: $failure';
                          });
                        }
                      },
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.link),
                label: Text(busy ? 'Testing…' : 'Test & save'),
              ),
            ],
          ),
        ),
      ),
    );
    url.dispose();
    key.dispose();
    name.dispose();
  }

  void _invalidateData(WidgetRef ref) {
    ref.invalidate(capabilitiesProvider);
    ref.invalidate(dashboardProvider);
    ref.invalidate(projectsProvider);
    ref.invalidate(servicesProvider);
    ref.invalidate(deploymentsProvider);
    ref.invalidate(serversProvider);
    ref.invalidate(backupsProvider);
    ref.invalidate(schedulesProvider);
    ref.invalidate(domainsProvider);
  }
}
