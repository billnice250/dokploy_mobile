import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/providers.dart';
import '../core/app_notice.dart';
import '../core/biometric_confirmation.dart';
import '../core/theme.dart';
import '../data/dokploy_api.dart';
import '../data/mock_repository.dart';
import '../data/real_repository.dart';
import '../data/tls_credentials.dart';
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
                      onEdit: () => _configureInstance(
                        context,
                        ref,
                        existing: instance,
                      ),
                      onRemove: () => _removeInstance(context, ref, instance),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () => _configureInstance(context, ref),
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
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.https_outlined),
                  title: Text('HTTPS required'),
                  subtitle: Text(
                      'Invalid TLS certificates are never accepted globally.'),
                ),
                const ListTile(
                  leading: Icon(Icons.key),
                  title: Text('API keys'),
                  subtitle: Text('Stored only in Keychain / Android Keystore'),
                ),
                const Divider(height: 1),
                ListTile(
                  onTap: () => _showApiKeyGuide(context),
                  leading: const Icon(Icons.help_outline_rounded),
                  title: const Text('API key setup & safety'),
                  subtitle: const Text(
                    'How to create, protect and revoke a Dokploy key',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
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
                  onTap: () => _openLink(context, _repositoryUri),
                  leading: const Icon(Icons.code_rounded),
                  title: const Text('Project repository'),
                  subtitle: const Text(
                    'Source code, feature requests and issue reports',
                  ),
                  trailing: const Icon(Icons.open_in_new_rounded),
                ),
                const Divider(height: 1),
                ListTile(
                  onTap: () => _openLink(context, _blogUri),
                  leading: const Icon(Icons.language_outlined),
                  title: const Text('Bill Nice — Blog & portfolio'),
                  subtitle: const Text('blog.billnice.it'),
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
    VoidCallback? onEdit,
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
                        onTap: onEdit,
                        child: const Row(
                          children: [
                            Icon(Icons.edit_outlined),
                            SizedBox(width: 10),
                            Text('Edit connection'),
                          ],
                        ),
                      ),
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
    final secrets = await store.secrets(instance.id);
    if (!_hasRequiredCredentials(instance, secrets)) {
      if (context.mounted) {
        DployGoNotice.show(
          context,
          message: 'This instance is missing required authentication data.',
          tone: DployGoNoticeTone.warning,
        );
      }
      return;
    }
    await store.setActive(instance.id);
    ref.read(currentInstanceProvider.notifier).state = instance;
    ref.read(repositoryProvider.notifier).state = RealDokployRepository(
      DokployApi.forInstance(instance: instance, secrets: secrets),
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

  Future<void> _configureInstance(
    BuildContext context,
    WidgetRef ref, {
    DokployInstance? existing,
  }) async {
    if (existing != null) {
      final authorized = await confirmSensitiveOperation(
        context,
        ref,
        reason: 'Confirm editing authentication for ${existing.name}.',
      );
      if (!authorized || !context.mounted) return;
    }
    final store = ref.read(instanceStoreProvider);
    final savedSecrets = existing == null
        ? const InstanceSecrets()
        : await store.secrets(existing.id);
    if (!context.mounted) return;
    final url = TextEditingController(text: existing?.baseUrl ?? '');
    final key = TextEditingController(text: savedSecrets.apiKey);
    final name = TextEditingController(text: existing?.name ?? 'My Dokploy');
    final certificatePassword = TextEditingController(
      text: savedSecrets.clientPkcs12Password,
    );
    var authMode = existing?.authMode ?? InstanceAuthMode.apiKey;
    var caPemBundle = savedSecrets.caPemBundle;
    var caFileName = existing?.caFileName ?? '';
    var clientPkcs12 = savedSecrets.clientPkcs12;
    var clientCertificateFileName = existing?.clientCertificateFileName ?? '';
    var caCertificates = <CertificateSummary>[];
    CertificateSummary? clientCertificate;
    String? certificateError;
    try {
      if (caPemBundle.isNotEmpty) {
        caCertificates = inspectTrustBundle(caPemBundle);
      }
      if (clientPkcs12 != null) {
        clientCertificate = await inspectClientPkcs12(
          clientPkcs12,
          certificatePassword.text,
        );
      }
    } catch (failure) {
      certificateError = 'Saved certificate validation failed: $failure';
    }
    if (!context.mounted) return;
    var busy = false;
    String? error = certificateError;
    Future<dynamic>? sheetDismissed;

    final saved = await showModalBottomSheet<
        ({DokployInstance instance, DokployApi api, bool activate})>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      showDragHandle: true,
      builder: (sheetContext) {
        sheetDismissed ??= ModalRoute.of(sheetContext)?.completed;
        return StatefulBuilder(
          builder: (sheetContext, setLocalState) => Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          existing == null
                              ? 'Add Dokploy instance'
                              : 'Edit ${existing.name}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cancel adding instance',
                        onPressed:
                            busy ? null : () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
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
                  DropdownButtonFormField<InstanceAuthMode>(
                    initialValue: authMode,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Authentication mode',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: InstanceAuthMode.apiKey,
                        child: Text('API key'),
                      ),
                      DropdownMenuItem(
                        value: InstanceAuthMode.apiKeyAndClientCertificate,
                        child: Text('API key + client certificate'),
                      ),
                      DropdownMenuItem(
                        value: InstanceAuthMode.clientCertificate,
                        child: Text('Client certificate only'),
                      ),
                    ],
                    onChanged: busy
                        ? null
                        : (value) => setLocalState(
                              () => authMode = value ?? authMode,
                            ),
                  ),
                  if (authMode != InstanceAuthMode.clientCertificate) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: key,
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration: const InputDecoration(labelText: 'API key'),
                    ),
                  ],
                  if (authMode != InstanceAuthMode.clientCertificate) ...[
                    const SizedBox(height: 10),
                    const Card(
                      child: ExpansionTile(
                        leading: Icon(Icons.key_outlined),
                        title: Text('How do I get an API key?'),
                        subtitle: Text('Portal steps and security notes'),
                        children: [
                          Padding(
                            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: _ApiKeyGuideContent(compact: true),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.verified_user_outlined),
                          title: const Text('Custom certificate authority'),
                          subtitle: Text(
                            caPemBundle.isEmpty
                                ? 'Optional PEM certificate list or P7B chain'
                                : caFileName.isEmpty
                                    ? 'Custom trust chain loaded'
                                    : caFileName,
                          ),
                          trailing: caPemBundle.isEmpty
                              ? const Icon(Icons.upload_file_outlined)
                              : IconButton(
                                  tooltip: 'Remove custom CA',
                                  onPressed: busy
                                      ? null
                                      : () => setLocalState(() {
                                            caPemBundle = '';
                                            caFileName = '';
                                            caCertificates = [];
                                          }),
                                  icon: const Icon(Icons.close_rounded),
                                ),
                          onTap: busy
                              ? null
                              : () async {
                                  try {
                                    final picked = await _pickFiles(
                                      const ['pem', 'crt', 'cer', 'p7b', 'p7c'],
                                      allowMultiple: true,
                                    );
                                    if (picked.isEmpty) return;
                                    final normalized = picked
                                        .map((file) =>
                                            normalizeTrustBundle(file.bytes))
                                        .join('\n');
                                    final certificates =
                                        inspectTrustBundle(normalized);
                                    validateCertificateValidity(certificates);
                                    setLocalState(() {
                                      caPemBundle = normalized;
                                      caCertificates = certificates;
                                      caFileName = picked
                                          .map((file) => file.name)
                                          .join(', ');
                                      error = null;
                                    });
                                  } catch (failure) {
                                    setLocalState(() => error =
                                        'Could not read CA chain: $failure');
                                  }
                                },
                        ),
                        for (final certificate in caCertificates)
                          _CertificateDetails(certificate: certificate),
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
                          child: Text(
                            'System roots stay enabled. The custom certificates apply only to this instance; hostname verification is never disabled.',
                            style: TextStyle(fontSize: 12, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (authMode != InstanceAuthMode.apiKey) ...[
                    const SizedBox(height: 10),
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.badge_outlined),
                            title: const Text('Client identity'),
                            subtitle: Text(
                              clientPkcs12 == null
                                  ? 'Select a PKCS#12 .p12 or .pfx file'
                                  : clientCertificateFileName.isEmpty
                                      ? 'Client certificate loaded'
                                      : clientCertificateFileName,
                            ),
                            trailing: clientPkcs12 == null
                                ? const Icon(Icons.upload_file_outlined)
                                : IconButton(
                                    tooltip: 'Remove client certificate',
                                    onPressed: busy
                                        ? null
                                        : () => setLocalState(() {
                                              clientPkcs12 = null;
                                              clientCertificateFileName = '';
                                              clientCertificate = null;
                                              certificatePassword.clear();
                                            }),
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                            onTap: busy
                                ? null
                                : () async {
                                    final files = await _pickFiles(
                                      const ['p12', 'pfx'],
                                    );
                                    if (files.isEmpty) return;
                                    final picked = files.first;
                                    setLocalState(() {
                                      clientPkcs12 = picked.bytes;
                                      clientCertificateFileName = picked.name;
                                      clientCertificate = null;
                                      error = null;
                                    });
                                    try {
                                      final summary = await inspectClientPkcs12(
                                        picked.bytes,
                                        certificatePassword.text,
                                      );
                                      if (!sheetContext.mounted) return;
                                      setLocalState(
                                        () => clientCertificate = summary,
                                      );
                                    } catch (failure) {
                                      if (!sheetContext.mounted) return;
                                      setLocalState(() => error =
                                          'Enter the correct certificate password, then validate: $failure');
                                    }
                                  },
                          ),
                          if (clientPkcs12 != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextField(
                                    controller: certificatePassword,
                                    obscureText: true,
                                    enableSuggestions: false,
                                    autocorrect: false,
                                    onChanged: (_) => setLocalState(
                                      () => clientCertificate = null,
                                    ),
                                    decoration: const InputDecoration(
                                      labelText: 'Certificate password',
                                      hintText: 'Leave empty if unprotected',
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  OutlinedButton.icon(
                                    onPressed: busy
                                        ? null
                                        : () async {
                                            try {
                                              final summary =
                                                  await inspectClientPkcs12(
                                                clientPkcs12!,
                                                certificatePassword.text,
                                              );
                                              if (!sheetContext.mounted) return;
                                              setLocalState(() {
                                                clientCertificate = summary;
                                                error = null;
                                              });
                                            } catch (failure) {
                                              if (!sheetContext.mounted) return;
                                              setLocalState(() => error =
                                                  'Client certificate validation failed: $failure');
                                            }
                                          },
                                    icon: const Icon(Icons.verified_outlined),
                                    label: Text(clientCertificate == null
                                        ? 'Validate certificate'
                                        : 'Certificate validated'),
                                  ),
                                ],
                              ),
                            ),
                          if (clientCertificate != null)
                            _CertificateDetails(
                              certificate: clientCertificate!,
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                            ),
                        ],
                      ),
                    ),
                    if (authMode == InstanceAuthMode.clientCertificate)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(6, 8, 6, 0),
                        child: Text(
                          'Client-certificate-only authentication requires a reverse proxy that authorizes the certificate. Dokploy may still return 401 when its API-key authentication is enabled.',
                          style: TextStyle(
                            color: DokployTheme.warning,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ),
                  ],
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
                            final needsApiKey =
                                authMode != InstanceAuthMode.clientCertificate;
                            final needsClientCertificate =
                                authMode != InstanceAuthMode.apiKey;
                            if (uri == null ||
                                uri.scheme != 'https' ||
                                uri.host.isEmpty ||
                                (needsApiKey && key.text.trim().isEmpty) ||
                                (needsClientCertificate &&
                                    clientPkcs12 == null)) {
                              setLocalState(
                                () => error =
                                    'Enter a valid HTTPS URL and all required authentication data.',
                              );
                              return;
                            }
                            setLocalState(() {
                              busy = true;
                              error = null;
                            });
                            try {
                              validateCertificateValidity(caCertificates);
                              if (needsClientCertificate) {
                                clientCertificate = await inspectClientPkcs12(
                                  clientPkcs12!,
                                  certificatePassword.text,
                                );
                                if (!sheetContext.mounted) return;
                                setLocalState(() {});
                              }
                              final instance = DokployInstance(
                                id: existing?.id ??
                                    DateTime.now()
                                        .microsecondsSinceEpoch
                                        .toString(),
                                name: name.text.trim().isEmpty
                                    ? uri.host
                                    : name.text.trim(),
                                baseUrl: normalized,
                                version: existing?.version ?? 'unknown',
                                authMode: authMode,
                                hasCustomCa: caPemBundle.isNotEmpty,
                                hasClientCertificate: clientPkcs12 != null,
                                caFileName: caFileName,
                                clientCertificateFileName:
                                    clientCertificateFileName,
                              );
                              final secrets = InstanceSecrets(
                                apiKey: key.text.trim(),
                                caPemBundle: caPemBundle,
                                clientPkcs12: clientPkcs12,
                                clientPkcs12Password: certificatePassword.text,
                              );
                              final api = DokployApi.forInstance(
                                instance: instance,
                                secrets: secrets,
                              );
                              await ref
                                  .read(instanceConnectionProbeProvider)(api);
                              final wasSelected = existing == null ||
                                  ref.read(currentInstanceProvider).id ==
                                      existing.id;
                              await store.save(
                                instance,
                                secrets.apiKey,
                                caPemBundle: secrets.caPemBundle,
                                clientPkcs12: secrets.clientPkcs12,
                                clientPkcs12Password:
                                    secrets.clientPkcs12Password,
                                setActiveInstance: wasSelected,
                              );
                              if (sheetContext.mounted) {
                                Navigator.pop(
                                  sheetContext,
                                  (
                                    instance: instance,
                                    api: api,
                                    activate: wasSelected,
                                  ),
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
                    label: Text(busy
                        ? 'Testing…'
                        : existing == null
                            ? 'Test & save'
                            : 'Test & update'),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: busy ? null : () => Navigator.pop(sheetContext),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    await sheetDismissed;
    url.dispose();
    key.dispose();
    name.dispose();
    certificatePassword.dispose();
    if (saved == null || !context.mounted) return;
    if (saved.activate) {
      ref.read(currentInstanceProvider.notifier).state = saved.instance;
      ref.read(repositoryProvider.notifier).state =
          RealDokployRepository(saved.api);
      _invalidateData(ref);
    }
    ref.invalidate(instancesProvider);
    await WidgetsBinding.instance.endOfFrame;
    if (context.mounted) {
      DployGoNotice.show(
        context,
        message: existing == null
            ? 'Dokploy instance connected.'
            : 'Connection settings updated.',
        tone: DployGoNoticeTone.success,
      );
    }
  }

  Future<List<({String name, Uint8List bytes})>> _pickFiles(
    List<String> extensions, {
    bool allowMultiple = false,
  }) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      withData: true,
      allowMultiple: allowMultiple,
    );
    if (result == null) return const [];
    final files = <({String name, Uint8List bytes})>[];
    for (final file in result.files) {
      final bytes = file.bytes ??
          (file.path == null ? null : await File(file.path!).readAsBytes());
      if (bytes == null || bytes.isEmpty) {
        throw FormatException('${file.name} is empty.');
      }
      files.add((name: file.name, bytes: bytes));
    }
    return files;
  }

  bool _hasRequiredCredentials(
    DokployInstance instance,
    InstanceSecrets secrets,
  ) {
    final needsApiKey = instance.authMode != InstanceAuthMode.clientCertificate;
    final needsClientCertificate = instance.authMode != InstanceAuthMode.apiKey;
    return (!needsApiKey || secrets.apiKey.isNotEmpty) &&
        (!needsClientCertificate || secrets.hasClientCertificate);
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

  Future<void> _showApiKeyGuide(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheetContext) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * .82,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 12, 10),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Dokploy API key setup',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close guide',
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                const Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 28),
                    child: _ApiKeyGuideContent(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _CertificateDetails extends StatelessWidget {
  const _CertificateDetails({
    required this.certificate,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 12),
  });

  final CertificateSummary certificate;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final expired = certificate.isExpired;
    final pending = certificate.isNotYetValid;
    final color =
        expired || pending ? DokployTheme.danger : DokployTheme.success;
    final status = expired
        ? 'Expired'
        : pending
            ? 'Not yet valid'
            : 'Valid';
    final dates = DateFormat('dd MMM yyyy');
    return Padding(
      padding: padding,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: DokployTheme.elevated.withValues(alpha: .55),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: DokployTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_rounded, size: 18, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    certificate.commonName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  status,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Valid ${dates.format(certificate.notBefore.toLocal())} — '
              '${dates.format(certificate.notAfter.toLocal())}',
              style: const TextStyle(color: DokployTheme.muted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            const Text(
              'SHA-1 thumbprint',
              style: TextStyle(color: DokployTheme.muted, fontSize: 11),
            ),
            const SizedBox(height: 3),
            SelectableText(
              certificate.sha1Thumbprint,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApiKeyGuideContent extends StatelessWidget {
  const _ApiKeyGuideContent({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GuideStep(
            number: 1,
            text: 'Sign in to your Dokploy web dashboard.',
            compact: compact,
          ),
          _GuideStep(
            number: 2,
            text: 'Open Profile, then find API/CLI Keys.',
            compact: compact,
          ),
          _GuideStep(
            number: 3,
            text:
                'Choose Generate New Key and give it a recognizable name, such as “DployGo Mobile”.',
            compact: compact,
          ),
          _GuideStep(
            number: 4,
            text: 'Copy the key when it is shown and paste it into DployGo.',
            compact: compact,
          ),
          SizedBox(height: compact ? 8 : 14),
          Container(
            padding: EdgeInsets.all(compact ? 10 : 14),
            decoration: BoxDecoration(
              color: DokployTheme.warning.withValues(alpha: .10),
              border: Border.all(
                color: DokployTheme.warning.withValues(alpha: .38),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.shield_outlined,
                  color: DokployTheme.warning,
                  size: 20,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Treat the key like a password. It acts with the permissions of its Dokploy account. Do not share it, paste it into issue reports, or commit it to source control.',
                    style: TextStyle(height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: compact ? 10 : 14),
          const _SafetyPoint(
            icon: Icons.lock_outline_rounded,
            text:
                'Stored locally in iOS Keychain or Android Keystore-backed secure storage.',
          ),
          const _SafetyPoint(
            icon: Icons.cloud_outlined,
            text:
                'Sent only to the HTTPS Dokploy URL you configure, using the x-api-key header.',
          ),
          const _SafetyPoint(
            icon: Icons.visibility_off_outlined,
            text:
                'Redacted from DployGo request logs and never included in notifications.',
          ),
          const _SafetyPoint(
            icon: Icons.delete_outline_rounded,
            text:
                'Removing an instance deletes its saved key from this device.',
          ),
          const _SafetyPoint(
            icon: Icons.block_outlined,
            text:
                'If the device or key may be compromised, delete the key in Dokploy immediately and generate a replacement.',
          ),
        ],
      );
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({
    required this.number,
    required this.text,
    required this.compact,
  });

  final int number;
  final String text;
  final bool compact;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: compact ? 7 : 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: compact ? 22 : 26,
              height: compact ? 22 : 26,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: DokployTheme.elevated,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$number',
                style: TextStyle(
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(height: 1.35))),
          ],
        ),
      );
}

class _SafetyPoint extends StatelessWidget {
  const _SafetyPoint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: DokployTheme.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: DokployTheme.muted,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      );
}
