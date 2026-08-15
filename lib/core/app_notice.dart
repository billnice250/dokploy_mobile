import 'package:flutter/material.dart';

import 'theme.dart';

enum DployGoNoticeTone { success, error, warning, info }

/// Branded, floating in-app feedback used instead of the platform SnackBar UI.
abstract final class DployGoNotice {
  static void show(
    BuildContext context, {
    required String message,
    DployGoNoticeTone tone = DployGoNoticeTone.info,
    String? title,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 18),
          padding: EdgeInsets.zero,
          duration: tone == DployGoNoticeTone.error
              ? const Duration(seconds: 6)
              : const Duration(seconds: 4),
          content: _NoticeCard(
            tone: tone,
            title: title ?? _defaultTitle(tone),
            message: message,
            onDismiss: messenger.hideCurrentSnackBar,
          ),
        ),
      );
  }

  static String _defaultTitle(DployGoNoticeTone tone) => switch (tone) {
        DployGoNoticeTone.success => 'Done',
        DployGoNoticeTone.error => 'Something went wrong',
        DployGoNoticeTone.warning => 'Attention',
        DployGoNoticeTone.info => 'DployGo',
      };
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.tone,
    required this.title,
    required this.message,
    required this.onDismiss,
  });

  final DployGoNoticeTone tone;
  final String title, message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (tone) {
      DployGoNoticeTone.success => (DokployTheme.success, Icons.check_rounded),
      DployGoNoticeTone.error => (
          DokployTheme.danger,
          Icons.priority_high_rounded
        ),
      DployGoNoticeTone.warning => (
          DokployTheme.warning,
          Icons.warning_amber_rounded
        ),
      DployGoNoticeTone.info => (
          Theme.of(context).colorScheme.primary,
          Icons.bolt_rounded
        ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xF21A1A1D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: .42)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: const TextStyle(
                      color: Color(0xFFB8B8C0),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Dismiss',
              onPressed: onDismiss,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, size: 18, color: Color(0xFF9999A2)),
            ),
          ],
        ),
      ),
    );
  }
}
