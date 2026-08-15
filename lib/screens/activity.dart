import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../domain/models.dart';

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deployments = ref.watch(deploymentsProvider);
    final capabilities = ref.watch(capabilitiesProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(deploymentsProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: capabilities?.deployments == false
          ? const Center(
              child: Text('Deployment activity is unavailable for this token.'),
            )
          : deployments.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('$error')),
              data: (items) => ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
                children: [
                  const SectionTitle('Deployment queue'),
                  ...items.map(
                    (deployment) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  StatusDot(deployment.status),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      deployment.service,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  Text(
                                    statusLabel(deployment.status),
                                    style: TextStyle(
                                        color: statusColor(deployment.status)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${deployment.branch} • ${deployment.commit}',
                                style:
                                    const TextStyle(color: DokployTheme.muted),
                              ),
                              if (deployment.message.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(deployment.message),
                              ],
                              if (deployment.status == HealthState.deploying &&
                                  capabilities?.cancelDeployments != false) ...[
                                const SizedBox(height: 14),
                                const LinearProgressIndicator(),
                                const SizedBox(height: 10),
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      _confirmCancel(context, ref, deployment),
                                  icon: const Icon(Icons.close),
                                  label: const Text('Cancel'),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () => context.push(
                                    '/deployment/${deployment.id}',
                                  ),
                                  icon: const Icon(Icons.subject),
                                  label: const Text('Details & logs'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _confirmCancel(
    BuildContext context,
    WidgetRef ref,
    DeploymentModel deployment,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel deployment?'),
        content:
            Text('Cancel the active deployment for ${deployment.service}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep running'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel deployment'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(repositoryProvider).cancelDeployment(deployment.id);
      ref.invalidate(deploymentsProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not cancel deployment: $error')),
        );
      }
    }
  }
}
