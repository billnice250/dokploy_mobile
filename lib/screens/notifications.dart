import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/providers.dart';
import '../core/theme.dart';
import '../domain/notifications.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final instance = ref.watch(currentInstanceProvider);
    final history = ref.watch(notificationHistoryProvider(instance.id));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Notification settings',
            onPressed: () => context.push('/notification-settings'),
            icon: const Icon(Icons.tune_rounded),
          ),
          if (history.valueOrNull?.any((item) => !item.read) ?? false)
            TextButton(
              onPressed: () async {
                await ref
                    .read(notificationStoreProvider)
                    .markAllRead(instanceId: instance.id);
                ref.invalidate(notificationHistoryProvider(instance.id));
              },
              child: const Text('Read all'),
            ),
        ],
      ),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Could not load alerts: $error')),
        data: (items) => items.isEmpty
            ? const _EmptyNotifications()
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) => _NotificationTile(
                  event: items[index],
                  onTap: () async {
                    await ref
                        .read(notificationStoreProvider)
                        .markRead(items[index].id);
                    ref.invalidate(notificationHistoryProvider(instance.id));
                    if (context.mounted) context.push(items[index].route);
                  },
                ),
              ),
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: DokployTheme.elevated,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: DokployTheme.border),
                ),
                child: const Icon(Icons.notifications_none_rounded, size: 31),
              ),
              const SizedBox(height: 18),
              Text('All quiet', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 7),
              const Text(
                'Deployment changes for this instance will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: DokployTheme.muted),
              ),
            ],
          ),
        ),
      );
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.event, required this.onTap});

  final NotificationEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (event.kind) {
      NotificationEventKind.started => (
          Icons.rocket_launch_outlined,
          DokployTheme.info
        ),
      NotificationEventKind.succeeded => (
          Icons.check_circle_outline_rounded,
          DokployTheme.success
        ),
      NotificationEventKind.failed => (
          Icons.error_outline_rounded,
          DokployTheme.danger
        ),
    };
    return Card(
      color: event.read ? DokployTheme.panel : DokployTheme.elevated,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(event.title,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        if (!event.read)
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: DokployTheme.info,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(event.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: DokployTheme.muted)),
                    const SizedBox(height: 8),
                    Text(
                      DateFormat('MMM d, HH:mm').format(event.createdAt),
                      style: const TextStyle(
                          color: DokployTheme.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
