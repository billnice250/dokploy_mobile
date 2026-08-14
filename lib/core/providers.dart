import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/instance_store.dart';
import '../data/mock_repository.dart';
import '../data/repository.dart';
import '../domain/models.dart';

const demoInstance = DokployInstance(
  id: 'demo',
  name: 'Demo Infrastructure',
  baseUrl: 'demo://local',
  version: 'demo',
  demo: true,
);

final instanceStoreProvider =
    Provider<InstanceStore>((ref) => const InstanceStore());
final instancesProvider = FutureProvider<List<DokployInstance>>(
  (ref) => ref.watch(instanceStoreProvider).load(),
);
final repositoryProvider = StateProvider<DokployRepository>(
  (ref) => MockDokployRepository(),
);
final currentInstanceProvider = StateProvider<DokployInstance>(
  (ref) => demoInstance,
);
final capabilitiesProvider = FutureProvider<CapabilitySet>(
  (ref) => ref.watch(repositoryProvider).capabilities(),
);
final dashboardProvider = FutureProvider(
  (ref) => ref.watch(repositoryProvider).dashboard(),
);
final projectsProvider = FutureProvider(
  (ref) => ref.watch(repositoryProvider).projects(),
);
final servicesProvider = FutureProvider(
  (ref) => ref.watch(repositoryProvider).services(),
);
final deploymentsProvider = FutureProvider(
  (ref) => ref.watch(repositoryProvider).deployments(),
);
final serversProvider = FutureProvider(
  (ref) => ref.watch(repositoryProvider).servers(),
);
final backupsProvider = FutureProvider(
  (ref) => ref.watch(repositoryProvider).backups(),
);
final schedulesProvider = FutureProvider(
  (ref) => ref.watch(repositoryProvider).schedules(),
);
final domainsProvider = FutureProvider(
  (ref) => ref.watch(repositoryProvider).domains(),
);
