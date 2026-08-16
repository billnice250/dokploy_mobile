import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/providers.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../domain/models.dart';

class TraefikRequestsScreen extends ConsumerStatefulWidget {
  const TraefikRequestsScreen({super.key});

  @override
  ConsumerState<TraefikRequestsScreen> createState() =>
      _TraefikRequestsScreenState();
}

class _TraefikRequestsScreenState extends ConsumerState<TraefikRequestsScreen> {
  int? statusClass;
  int? exactStatus;
  String search = '';

  static const commonStatuses = <int>[
    200,
    201,
    204,
    301,
    302,
    400,
    401,
    403,
    404,
    429,
    500,
    502,
    503,
    504,
  ];

  @override
  Widget build(BuildContext context) {
    final requests = ref.watch(traefikRequestsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Traefik requests'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(traefikRequestsProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(traefikRequestsProvider);
          await ref.read(traefikRequestsProvider.future);
        },
        child: requests.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 90),
              const Icon(Icons.sync_problem, size: 38),
              const SizedBox(height: 12),
              Text('Could not read Traefik requests',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: DokployTheme.muted)),
            ],
          ),
          data: (page) => _content(context, page),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, TraefikRequestPage page) {
    if (!page.enabled) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: const [
          SizedBox(height: 70),
          GlassPanel(
            child: Column(
              children: [
                Icon(Icons.route_outlined, size: 38, color: DokployTheme.muted),
                SizedBox(height: 12),
                Text('Request capture is disabled',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                SizedBox(height: 8),
                Text(
                  'Enable Requests in the Dokploy portal, then reload Traefik once so access logging is applied.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: DokployTheme.muted),
                ),
              ],
            ),
          ),
        ],
      );
    }
    final query = search.trim().toLowerCase();
    final filtered = page.items.where((item) {
      if (statusClass != null && item.statusCode ~/ 100 != statusClass) {
        return false;
      }
      if (exactStatus != null && item.statusCode != exactStatus) return false;
      return query.isEmpty ||
          item.host.toLowerCase().contains(query) ||
          item.path.toLowerCase().contains(query) ||
          item.service.toLowerCase().contains(query);
    }).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        GlassPanel(
          child: Row(
            children: [
              const Icon(Icons.swap_vert_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${page.totalCount} captured requests',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const Text('Live refresh every 4 seconds',
                        style:
                            TextStyle(color: DokployTheme.muted, fontSize: 12)),
                  ],
                ),
              ),
              const StatusDot(HealthState.healthy),
            ],
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          onChanged: (value) => setState(() => search = value),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Filter host, path or service',
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final entry in const <(int?, String)>[
                (null, 'All'),
                (1, '1xx'),
                (2, '2xx'),
                (3, '3xx'),
                (4, '4xx'),
                (5, '5xx'),
              ]) ...[
                ChoiceChip(
                  label: Text(entry.$2),
                  selected: statusClass == entry.$1,
                  onSelected: (_) => setState(() {
                    statusClass = entry.$1;
                    if (exactStatus != null &&
                        exactStatus! ~/ 100 != statusClass) {
                      exactStatus = null;
                    }
                  }),
                ),
                const SizedBox(width: 7),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int?>(
          initialValue: exactStatus,
          decoration: const InputDecoration(
            labelText: 'Common HTTP code',
            prefixIcon: Icon(Icons.filter_alt_outlined),
          ),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('Any code')),
            ...commonStatuses.map(
              (code) => DropdownMenuItem<int?>(
                value: code,
                child: Text('$code  ${_statusName(code)}'),
              ),
            ),
          ],
          onChanged: (value) => setState(() {
            exactStatus = value;
            if (value != null) statusClass = value ~/ 100;
          }),
        ),
        const SectionTitle('Latest traffic'),
        if (filtered.isEmpty)
          const GlassPanel(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text('No requests match these filters.'),
              ),
            ),
          )
        else
          for (final item in filtered)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _RequestTile(
                item,
                onTap: () => _showDetails(context, item),
              ),
            ),
      ],
    );
  }

  void _showDetails(BuildContext context, TraefikRequestModel item) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${item.method} ${item.path}',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              _detail('Status',
                  '${item.statusCode} ${_statusName(item.statusCode)}'),
              _detail('Host', item.host),
              _detail('Duration', '${item.durationMs.toStringAsFixed(1)} ms'),
              _detail('Client', item.clientHost),
              _detail('Router', item.router),
              _detail('Service', item.service),
              _detail('Protocol', item.protocol),
              _detail('Time', item.timestamp.toLocal().toString()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detail(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 82,
              child: Text(label,
                  style: const TextStyle(color: DokployTheme.muted)),
            ),
            Expanded(child: SelectableText(value.isEmpty ? '—' : value)),
          ],
        ),
      );
}

class _RequestTile extends StatelessWidget {
  const _RequestTile(this.item, {required this.onTap});

  final TraefikRequestModel item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GlassPanel(
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          leading: Container(
            width: 48,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
            decoration: BoxDecoration(
              color: _statusColor(item.statusCode).withValues(alpha: .12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('${item.statusCode}',
                style: TextStyle(
                    color: _statusColor(item.statusCode),
                    fontWeight: FontWeight.w800)),
          ),
          title: Text('${item.method}  ${item.path}',
              maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            '${item.host}  •  ${item.durationMs.toStringAsFixed(0)} ms  •  ${DateFormat.Hms().format(item.timestamp.toLocal())}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.chevron_right),
        ),
      );
}

Color _statusColor(int code) => switch (code ~/ 100) {
      2 => DokployTheme.success,
      3 => const Color(0xFF60A5FA),
      4 => DokployTheme.warning,
      5 => DokployTheme.danger,
      _ => DokployTheme.muted,
    };

String _statusName(int code) => switch (code) {
      200 => 'OK',
      201 => 'Created',
      204 => 'No Content',
      301 => 'Moved Permanently',
      302 => 'Found',
      400 => 'Bad Request',
      401 => 'Unauthorized',
      403 => 'Forbidden',
      404 => 'Not Found',
      429 => 'Too Many Requests',
      500 => 'Internal Server Error',
      502 => 'Bad Gateway',
      503 => 'Service Unavailable',
      504 => 'Gateway Timeout',
      _ => '',
    };
