import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/providers.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../domain/models.dart';

class DeploymentDetailScreen extends ConsumerStatefulWidget {
  const DeploymentDetailScreen({super.key, required this.deploymentId});

  final String deploymentId;

  @override
  ConsumerState<DeploymentDetailScreen> createState() =>
      _DeploymentDetailScreenState();
}

class _DeploymentDetailScreenState
    extends ConsumerState<DeploymentDetailScreen> {
  final _scrollController = ScrollController();
  Timer? _refreshTimer;
  Future<List<String>>? _logsRequest;
  List<String> _loadedLogs = const [];
  int _tail = 500;
  String _search = '';
  bool _autoRefresh = false;

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<List<String>> _loadLogs() async {
    final logs = await ref
        .read(repositoryProvider)
        .deploymentLogs(widget.deploymentId, tail: _tail);
    if (mounted) {
      setState(() => _loadedLogs = logs);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
    return logs;
  }

  void _reload() => setState(() => _logsRequest = _loadLogs());

  void _toggleAutoRefresh() {
    setState(() => _autoRefresh = !_autoRefresh);
    _refreshTimer?.cancel();
    if (_autoRefresh) {
      _reload();
      _refreshTimer = Timer.periodic(
        const Duration(seconds: 3),
        (_) {
          if (mounted) _reload();
        },
      );
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final deployments = ref.watch(deploymentsProvider);
    final deployment = deployments.valueOrNull
        ?.where((item) => item.id == widget.deploymentId)
        .firstOrNull;
    _logsRequest ??= _loadLogs();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Deployment'),
        actions: [
          IconButton(
            tooltip: 'Refresh deployment',
            onPressed: () {
              ref.invalidate(deploymentsProvider);
              _reload();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: deployment == null
          ? deployments.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('$error')),
              data: (_) => const Center(child: Text('Deployment not found.')),
            )
          : Column(
              children: [
                _DeploymentSummary(deployment),
                const Divider(height: 1),
                _LogToolbar(
                  tail: _tail,
                  autoRefresh: _autoRefresh,
                  onSearch: (value) =>
                      setState(() => _search = value.toLowerCase()),
                  onTailChanged: (value) {
                    _tail = value;
                    _reload();
                  },
                  onToggleAutoRefresh: _toggleAutoRefresh,
                  onCopyAll: _copyAll,
                  onRefresh: _reload,
                ),
                Expanded(child: _buildLogs()),
              ],
            ),
    );
  }

  Widget _buildLogs() => FutureBuilder<List<String>>(
        future: _logsRequest,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done &&
              _loadedLogs.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError && _loadedLogs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child:
                    Text('Could not load deployment logs: ${snapshot.error}'),
              ),
            );
          }
          final lines = _loadedLogs
              .where((line) =>
                  _search.isEmpty || line.toLowerCase().contains(_search))
              .toList();
          if (lines.isEmpty) {
            return const Center(child: Text('No matching log lines.'));
          }
          return Container(
            color: const Color(0xFF070708),
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(14),
              itemCount: lines.length,
              itemBuilder: (context, index) => GestureDetector(
                onLongPress: () => _copyLine(lines[index]),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: SelectableText(
                    lines[index],
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12.2,
                      color: _logColor(lines[index]),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );

  Future<void> _copyLine(String line) async {
    await Clipboard.setData(ClipboardData(text: line));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Log line copied.')),
      );
    }
  }

  Future<void> _copyAll() async {
    await Clipboard.setData(ClipboardData(text: _loadedLogs.join('\n')));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_loadedLogs.length} log lines copied.')),
      );
    }
  }
}

class _DeploymentSummary extends StatelessWidget {
  const _DeploymentSummary(this.deployment);

  final DeploymentModel deployment;

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('d MMM, HH:mm:ss');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Card(
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
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    statusLabel(deployment.status),
                    style: TextStyle(color: statusColor(deployment.status)),
                  ),
                ],
              ),
              if (deployment.title.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(deployment.title),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 18,
                runSpacing: 8,
                children: [
                  _Fact(
                      'Started',
                      timeFormat.format(
                        deployment.startedAt ?? deployment.createdAt,
                      )),
                  _Fact('Duration', _duration(deployment)),
                  if (deployment.branch.isNotEmpty)
                    _Fact('Branch', deployment.branch),
                  if (deployment.commit.isNotEmpty)
                    _Fact('Commit', deployment.commit),
                ],
              ),
              if (deployment.errorMessage.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: DokployTheme.danger.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    deployment.errorMessage,
                    style: const TextStyle(color: Color(0xFFFCA5A5)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _duration(DeploymentModel deployment) {
    final seconds = deployment.durationSeconds;
    if (seconds <= 0) return '—';
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return minutes == 0 ? '${remainder}s' : '${minutes}m ${remainder}s';
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);

  final String label, value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: DokployTheme.muted)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      );
}

class _LogToolbar extends StatelessWidget {
  const _LogToolbar({
    required this.tail,
    required this.autoRefresh,
    required this.onSearch,
    required this.onTailChanged,
    required this.onToggleAutoRefresh,
    required this.onCopyAll,
    required this.onRefresh,
  });

  final int tail;
  final bool autoRefresh;
  final ValueChanged<String> onSearch;
  final ValueChanged<int> onTailChanged;
  final VoidCallback onToggleAutoRefresh, onCopyAll, onRefresh;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(
          children: [
            TextField(
              onChanged: onSearch,
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search),
                hintText: 'Search loaded deployment logs',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                PopupMenuButton<int>(
                  tooltip: 'Tail count',
                  initialValue: tail,
                  onSelected: onTailChanged,
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 100, child: Text('Last 100')),
                    PopupMenuItem(value: 500, child: Text('Last 500')),
                    PopupMenuItem(value: 1000, child: Text('Last 1,000')),
                    PopupMenuItem(value: 5000, child: Text('Last 5,000')),
                  ],
                  child: Chip(label: Text('$tail lines')),
                ),
                const Spacer(),
                IconButton(
                  tooltip: autoRefresh ? 'Pause refresh' : 'Auto-refresh',
                  onPressed: onToggleAutoRefresh,
                  icon: Icon(autoRefresh ? Icons.pause : Icons.play_arrow),
                ),
                IconButton(
                  tooltip: 'Copy all loaded logs',
                  onPressed: onCopyAll,
                  icon: const Icon(Icons.copy_all_outlined),
                ),
                IconButton(
                  tooltip: 'Refresh logs',
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ],
        ),
      );
}

Color _logColor(String line) {
  final normalized = line.toLowerCase();
  if (normalized.contains('error') || normalized.contains('fatal')) {
    return const Color(0xFFFCA5A5);
  }
  if (normalized.contains('warn')) return const Color(0xFFFCD34D);
  if (normalized.contains('success') || normalized.contains('completed')) {
    return const Color(0xFF86EFAC);
  }
  return const Color(0xFFD6D6DA);
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
