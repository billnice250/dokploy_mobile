import 'package:flutter/services.dart';

/// Sends a safe, last-refreshed infrastructure summary to the native home
/// screen widget. Instance credentials and raw Dokploy responses never cross
/// this channel.
class HomeWidgetBridge {
  HomeWidgetBridge._();

  static const _channel = MethodChannel('dploygo/home_widget');

  static Future<bool> update({
    required String instanceName,
    required int running,
    required int stopped,
    required int failed,
  }) async {
    try {
      return await _channel.invokeMethod<bool>('updateSummary', {
            'instanceName': instanceName,
            'running': running,
            'stopped': stopped,
            'failed': failed,
            'updatedAt': DateTime.now().toIso8601String(),
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
