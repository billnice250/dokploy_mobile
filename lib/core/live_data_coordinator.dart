import 'dart:async';

import 'package:flutter/widgets.dart';

class LiveDataCoordinator with WidgetsBindingObserver {
  LiveDataCoordinator({required this.onRefresh});

  final void Function({required bool includeInfrastructure}) onRefresh;
  Timer? _timer;
  bool _enabled = false;
  bool _foreground = true;
  int _ticks = 0;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _refresh());
  }

  void configure({required bool enabled}) {
    final becameEnabled = !_enabled && enabled;
    _enabled = enabled;
    if (becameEnabled) _refresh(includeInfrastructure: true);
  }

  void _refresh({bool includeInfrastructure = false}) {
    if (!_enabled || !_foreground) return;
    _ticks++;
    onRefresh(
      includeInfrastructure: includeInfrastructure || _ticks % 3 == 0,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) _refresh(includeInfrastructure: true);
  }

  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}
