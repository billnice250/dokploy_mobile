import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';
import '../core/providers.dart';
import '../core/biometric_confirmation.dart';
import '../domain/terminal_session.dart';

class TerminalScreen extends ConsumerStatefulWidget {
  const TerminalScreen(
      {super.key, required this.title, this.serverId, this.containerId});
  final String title;
  final String? serverId;
  final String? containerId;
  @override
  ConsumerState<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends ConsumerState<TerminalScreen>
    with WidgetsBindingObserver {
  final _terminal = Terminal(maxLines: 2000);
  final _username = TextEditingController(text: 'root');
  final _port = TextEditingController(text: '22');
  TerminalSession? _session;
  StreamSubscription<String>? _subscription;
  bool _connecting = false;
  String _status = 'Disconnected';
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _terminal.onOutput = (data) => _session?.write(data);
    _terminal.onResize =
        (cols, rows, width, height) => _session?.resize(cols, rows);
  }

  Future<void> _disconnect() async {
    _generation++;
    final session = _session;
    _session = null;
    final subscription = _subscription;
    _subscription = null;
    if (mounted) {
      setState(() {
        _connecting = false;
        _status = 'Disconnected';
      });
    }
    await subscription?.cancel();
    await session?.close();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_disconnect());
  }

  Future<void> _connect() async {
    final port = int.tryParse(_port.text);
    if (widget.serverId == null &&
        widget.containerId == null &&
        (port == null ||
            port < 1 ||
            port > 65535 ||
            _username.text.trim().isEmpty)) {
      setState(() => _status = 'Enter a username and a port from 1 to 65535.');
      return;
    }
    final repository = ref.read(repositoryProvider);
    final authorized = ref.read(currentInstanceProvider).demo ||
        await confirmSensitiveOperation(context, ref,
            reason: 'Open an interactive shell on ${widget.title}.');
    if (!authorized || !mounted || repository != ref.read(repositoryProvider)) {
      return;
    }
    final generation = ++_generation;
    setState(() {
      _connecting = true;
      _status = 'Connecting…';
    });
    try {
      final session = await repository.openTerminal(
          serverId: widget.serverId,
          containerId: widget.containerId,
          username: _username.text.trim(),
          port: port ?? 22);
      if (!mounted || generation != _generation) {
        await session.close();
        return;
      }
      _session = session;
      _subscription = session.output.listen(_terminal.write,
          onError: (_) => _ended(
              'Connection failed. Check terminal permissions and server availability.'),
          onDone: () => _ended(
              'Session closed. Check permissions if no shell appeared.'));
      session.resize(_terminal.viewWidth, _terminal.viewHeight);
      setState(() {
        _connecting = false;
        _status = 'Connected';
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _connecting = false;
          _status =
              'Unable to connect. Check terminal permissions and server availability.';
        });
      }
    }
  }

  void _ended(String message) {
    final session = _session;
    _session = null;
    unawaited(session?.close());
    if (mounted) {
      setState(() {
        _connecting = false;
        _status = message;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    unawaited(_subscription?.cancel());
    unawaited(_session?.close());
    _username.dispose();
    _port.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(repositoryProvider, (_, next) => unawaited(_disconnect()));
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), actions: [
        TextButton(
            onPressed: _connecting
                ? null
                : _session == null
                    ? _connect
                    : _disconnect,
            child: Text(_session == null ? 'Connect' : 'Disconnect')),
      ]),
      body: SafeArea(
          child: Column(children: [
        if (_session == null &&
            widget.serverId == null &&
            widget.containerId == null)
          Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Expanded(
                    child: TextField(
                        controller: _username,
                        decoration:
                            const InputDecoration(labelText: 'SSH username'))),
                const SizedBox(width: 12),
                SizedBox(
                    width: 110,
                    child: TextField(
                        controller: _port,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'SSH port'))),
              ])),
        ListTile(
            dense: true,
            leading: Icon(Icons.circle,
                size: 10,
                color: _session == null ? Colors.orange : Colors.green),
            title: Text(_status),
            subtitle: const Text(
                'Shell access • disconnects when you leave the app')),
        Expanded(
            child: ColoredBox(
                color: const Color(0xFF101216),
                child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: TerminalView(_terminal,
                        autofocus: true,
                        textStyle: const TerminalStyle(fontSize: 13))))),
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final key in {
                'Esc': '\x1b',
                'Tab': '\t',
                'Ctrl-C': '\x03',
                'Ctrl-D': '\x04',
                '↑': '\x1b[A',
                '↓': '\x1b[B',
                '←': '\x1b[D',
                '→': '\x1b[C'
              }.entries)
                TextButton(
                    onPressed: _session == null
                        ? null
                        : () => _session!.write(key.value),
                    child: Text(key.key)),
            ])),
      ])),
    );
  }
}
