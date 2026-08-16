import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/appearance.dart';
import 'core/providers.dart';
import 'core/local_notifications.dart';
import 'data/dokploy_api.dart';
import 'data/instance_store.dart';
import 'data/real_repository.dart';
import 'data/repository.dart';
import 'data/tls_credentials.dart';
import 'domain/models.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalNotificationService.instance.initialize();
  final bootstrap = await _restoreActiveInstance();
  const appearanceStore = AppearanceStore();
  final initialThemeMode = await appearanceStore.load();
  runApp(
    ProviderScope(
      overrides: [
        themeModeProvider.overrideWith(
          (ref) => AppearanceController(
            store: appearanceStore,
            initialMode: initialThemeMode,
          ),
        ),
        if (bootstrap != null) ...[
          currentInstanceProvider.overrideWith((ref) => bootstrap.instance),
          repositoryProvider.overrideWith((ref) => bootstrap.repository),
        ],
      ],
      child: const DokployMobileApp(),
    ),
  );
}

Future<({DokployInstance instance, DokployRepository repository})?>
    _restoreActiveInstance() async {
  try {
    const store = InstanceStore();
    final instances = await store.load();
    final activeId = await store.activeId();
    if (activeId == null) return null;
    final active = instances.where((item) => item.id == activeId).firstOrNull;
    if (active == null) return null;
    final secrets = await store.secrets(active.id);
    if (!_hasRequiredCredentials(active, secrets)) return null;
    return (
      instance: active,
      repository: RealDokployRepository(
        DokployApi.forInstance(instance: active, secrets: secrets),
      ),
    );
  } catch (_) {
    // Secure storage can be unavailable on an unsupported host. Demo mode is a
    // safe startup fallback and the user can retry from instance settings.
    return null;
  }
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

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
