import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/local_notifications.dart';
import '../core/app_notice.dart';
import '../core/providers.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../domain/notifications.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final instance = ref.watch(currentInstanceProvider);
    final asyncPreferences =
        ref.watch(notificationPreferencesProvider(instance.id));
    return Scaffold(
      appBar: AppBar(title: const Text('Deployment alerts')),
      body: asyncPreferences.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Could not load settings: $error')),
        data: (preferences) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _IntroCard(instanceName: instance.name),
            const SizedBox(height: 18),
            _Section(
              title: 'Alerts',
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    title: const Text('Deployment notifications'),
                    subtitle: Text(instance.demo
                        ? 'Connect a real instance to enable alerts.'
                        : 'Monitor ${instance.name} for status changes.'),
                    value: preferences.enabled && !instance.demo,
                    onChanged: instance.demo
                        ? null
                        : (enabled) async {
                            if (enabled) {
                              final granted = await LocalNotificationService
                                  .instance
                                  .requestPermission();
                              if (!granted && context.mounted) {
                                DployGoNotice.show(
                                  context,
                                  message:
                                      'Notification permission was not granted. Alerts remain in the in-app center.',
                                  tone: DployGoNoticeTone.warning,
                                );
                              }
                            }
                            await _save(ref, instance.id,
                                preferences.copyWith(enabled: enabled));
                          },
                  ),
                  const Divider(height: 1),
                  RadioGroup<NotificationDeliveryMode>(
                    groupValue: preferences.deliveryMode,
                    onChanged: (mode) {
                      if (mode == NotificationDeliveryMode.polling) {
                        _save(ref, instance.id,
                            preferences.copyWith(deliveryMode: mode));
                      }
                    },
                    child: const Column(
                      children: [
                        RadioListTile(
                          value: NotificationDeliveryMode.polling,
                          title: Text('Poll while app is open'),
                          subtitle: Text(
                              'Works now. iOS may pause checks when the app is in the background.'),
                        ),
                        RadioListTile(
                          value: NotificationDeliveryMode.push,
                          enabled: false,
                          title: Row(
                            children: [
                              Expanded(child: Text('Reliable push')),
                              UpcomingBadge(),
                            ],
                          ),
                          subtitle:
                              Text('Requires the optional Dokploy relay.'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (preferences.deliveryMode == NotificationDeliveryMode.push) ...[
              const SizedBox(height: 12),
              const _RelayCard(),
            ],
            const SizedBox(height: 18),
            _Section(
              title: 'Polling',
              child: ListTile(
                enabled: preferences.deliveryMode ==
                    NotificationDeliveryMode.polling,
                leading: const Icon(Icons.refresh_rounded),
                title: const Text('Check every'),
                trailing: DropdownButton<int>(
                  value: preferences.pollSeconds,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 30, child: Text('30 seconds')),
                    DropdownMenuItem(value: 60, child: Text('1 minute')),
                    DropdownMenuItem(value: 300, child: Text('5 minutes')),
                    DropdownMenuItem(value: 900, child: Text('15 minutes')),
                  ],
                  onChanged: preferences.deliveryMode ==
                          NotificationDeliveryMode.polling
                      ? (seconds) {
                          if (seconds != null) {
                            _save(ref, instance.id,
                                preferences.copyWith(pollSeconds: seconds));
                          }
                        }
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 18),
            _Section(
              title: 'Quiet hours',
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    title: const Text('Silence device alerts'),
                    subtitle: const Text(
                        'Events are still saved in the notification center.'),
                    value: preferences.quietHoursEnabled,
                    onChanged: (value) => _save(ref, instance.id,
                        preferences.copyWith(quietHoursEnabled: value)),
                  ),
                  if (preferences.quietHoursEnabled) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.bedtime_outlined),
                      title: const Text('Starts'),
                      trailing: Text(_timeLabel(preferences.quietStartMinutes)),
                      onTap: () => _pickTime(
                        context,
                        ref,
                        instance.id,
                        preferences,
                        start: true,
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.wb_sunny_outlined),
                      title: const Text('Ends'),
                      trailing: Text(_timeLabel(preferences.quietEndMinutes)),
                      onTap: () => _pickTime(
                        context,
                        ref,
                        instance.id,
                        preferences,
                        start: false,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            _Section(
              title: 'Events for ${instance.name}',
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    secondary: const Icon(Icons.rocket_launch_outlined,
                        color: DokployTheme.info),
                    title: const Text('Deployment started'),
                    value: preferences.notifyStarted,
                    onChanged: (value) => _save(ref, instance.id,
                        preferences.copyWith(notifyStarted: value)),
                  ),
                  SwitchListTile.adaptive(
                    secondary: const Icon(Icons.check_circle_outline,
                        color: DokployTheme.success),
                    title: const Text('Deployment succeeded'),
                    value: preferences.notifySucceeded,
                    onChanged: (value) => _save(ref, instance.id,
                        preferences.copyWith(notifySucceeded: value)),
                  ),
                  SwitchListTile.adaptive(
                    secondary: const Icon(Icons.error_outline,
                        color: DokployTheme.danger),
                    title: const Text('Deployment failed'),
                    value: preferences.notifyFailed,
                    onChanged: (value) => _save(ref, instance.id,
                        preferences.copyWith(notifyFailed: value)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _save(
    WidgetRef ref,
    String instanceId,
    NotificationPreferences preferences,
  ) async {
    await ref
        .read(notificationStoreProvider)
        .savePreferences(instanceId, preferences);
    ref.invalidate(notificationPreferencesProvider(instanceId));
  }

  static Future<void> _pickTime(
    BuildContext context,
    WidgetRef ref,
    String instanceId,
    NotificationPreferences preferences, {
    required bool start,
  }) async {
    final minutes =
        start ? preferences.quietStartMinutes : preferences.quietEndMinutes;
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (selected == null) return;
    final nextMinutes = selected.hour * 60 + selected.minute;
    await _save(
      ref,
      instanceId,
      start
          ? preferences.copyWith(quietStartMinutes: nextMinutes)
          : preferences.copyWith(quietEndMinutes: nextMinutes),
    );
  }

  static String _timeLabel(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.instanceName});

  final String instanceName;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              DokployTheme.elevatedOf(context).withValues(alpha: .9),
              DokployTheme.panelOf(context).withValues(alpha: .7),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: DokployTheme.borderOf(context)),
        ),
        child: Row(
          children: [
            const Icon(Icons.notifications_active_outlined, size: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Know when a deploy changes',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(instanceName,
                      style: TextStyle(color: DokployTheme.mutedOf(context))),
                ],
              ),
            ),
          ],
        ),
      );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 9),
            child: Text(title,
                style: TextStyle(
                    fontSize: 13,
                    color: DokployTheme.mutedOf(context),
                    fontWeight: FontWeight.w600)),
          ),
          Card(child: child),
        ],
      );
}

class _RelayCard extends StatelessWidget {
  const _RelayCard();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: DokployTheme.info.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: DokployTheme.info.withValues(alpha: .28)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.cloud_off_outlined, color: DokployTheme.info),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Relay not paired yet. The upcoming relay will accept Dokploy webhooks and deliver reliable push notifications to this device.',
                style: TextStyle(
                    color: DokployTheme.mutedOf(context), height: 1.35),
              ),
            ),
          ],
        ),
      );
}
