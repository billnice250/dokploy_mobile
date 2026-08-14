import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/providers.dart';
import 'data/dokploy_api.dart';
import 'data/instance_store.dart';
import 'data/real_repository.dart';
import 'data/repository.dart';
import 'domain/models.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final bootstrap = await _restoreActiveInstance();
  runApp(
    ProviderScope(
      overrides: [
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
    final apiKey = await store.apiKey(active.id);
    if (apiKey == null || apiKey.isEmpty) return null;
    return (
      instance: active,
      repository: RealDokployRepository(
        DokployApi(baseUrl: active.baseUrl, apiKey: apiKey),
      ),
    );
  } catch (_) {
    // Secure storage can be unavailable on an unsupported host. Demo mode is a
    // safe startup fallback and the user can retry from instance settings.
    return null;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
