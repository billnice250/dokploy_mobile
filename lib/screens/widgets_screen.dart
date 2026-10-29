import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../core/theme.dart';
import '../domain/models.dart';

class WidgetsScreen extends ConsumerWidget {
  const WidgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(dashboardProvider);
    final instance = ref.watch(currentInstanceProvider);
    final platform = Theme.of(context).platform;
    final addInstructions = switch (platform) {
      TargetPlatform.iOS ||
      TargetPlatform.macOS =>
        'Touch and hold the Home Screen, tap Edit, choose Add Widget, then select DployGo Status.',
      _ =>
        'Touch and hold an empty area of the Home Screen, open Widgets, then add DployGo Status.',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Home screen widget')),
      body: snapshot.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load widget data: $error'),
          ),
        ),
        data: (data) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const Text(
              'At a glance',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Keep the latest service health summary on your Home Screen.',
              style: TextStyle(color: DokployTheme.muted),
            ),
            const SizedBox(height: 18),
            _WidgetPreview(data: data, instanceName: instance.name),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.add_to_home_screen_outlined),
                        SizedBox(width: 10),
                        Text(
                          'Add the widget',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(addInstructions),
                    const SizedBox(height: 12),
                    const Text(
                      'The widget shows the last summary loaded by DployGo. Open or refresh the app to update it. Tapping the widget opens DployGo.',
                      style: TextStyle(
                        color: DokployTheme.muted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: () async {
                        ref.invalidate(dashboardProvider);
                        await ref.read(dashboardProvider.future);
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh widget data'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline, size: 17),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Only the instance label and service counts are shared with the system widget. API keys, server URLs, and raw responses are not shared.',
                    style: TextStyle(color: DokployTheme.muted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WidgetPreview extends StatelessWidget {
  const _WidgetPreview({required this.data, required this.instanceName});

  final DashboardSnapshot data;
  final String instanceName;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 176),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF141417),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF34343A)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 22,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.water, size: 17, color: Colors.white),
                const SizedBox(width: 8),
                const Text(
                  'DPLOYGO  •  INFRASTRUCTURE',
                  style: TextStyle(
                    color: Color(0xFFA1A1AA),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .8,
                  ),
                ),
                const Spacer(),
                Icon(
                  data.failed > 0
                      ? Icons.error_rounded
                      : Icons.check_circle_rounded,
                  size: 18,
                  color: data.failed > 0
                      ? DokployTheme.warning
                      : DokployTheme.success,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              instanceName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _WidgetMetric('RUNNING', data.running, DokployTheme.success),
                _WidgetMetric('STOPPED', data.stopped, DokployTheme.warning),
                _WidgetMetric('FAILED', data.failed, DokployTheme.danger),
              ],
            ),
          ],
        ),
      );
}

class _WidgetMetric extends StatelessWidget {
  const _WidgetMetric(this.label, this.value, this.color);

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: TextStyle(
                color: color,
                fontSize: 25,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFA1A1AA),
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: .5,
              ),
            ),
          ],
        ),
      );
}
