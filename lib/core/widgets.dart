import 'dart:ui';

import 'package:flutter/material.dart';
import '../domain/models.dart';
import 'theme.dart';

Color statusColor(HealthState s) => switch (s) {
      HealthState.healthy => DokployTheme.success,
      HealthState.warning => DokployTheme.warning,
      HealthState.failed => DokployTheme.danger,
      HealthState.stopped => DokployTheme.muted,
      HealthState.deploying => DokployTheme.info,
      _ => DokployTheme.muted
    };
String statusLabel(HealthState s) =>
    s.name[0].toUpperCase() + s.name.substring(1);

class StatusDot extends StatelessWidget {
  const StatusDot(this.state, {super.key, this.size = 9});
  final HealthState state;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          color: statusColor(state),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: statusColor(state).withValues(alpha: .35),
              blurRadius: 8,
            )
          ]));
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext c) => Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Row(children: [
        Expanded(
            child: Text(title.toUpperCase(),
                style: Theme.of(c)
                    .textTheme
                    .labelSmall
                    ?.copyWith(letterSpacing: 1.1, color: DokployTheme.muted))),
        if (trailing != null) trailing!
      ]));
}

class MetricCard extends StatelessWidget {
  const MetricCard(
      {super.key,
      required this.label,
      required this.value,
      this.icon,
      this.accent});
  final String label, value;
  final IconData? icon;
  final Color? accent;
  @override
  Widget build(BuildContext c) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (icon != null)
              Icon(icon, size: 18, color: accent ?? DokployTheme.muted),
            const Spacer(),
            Text(value,
                style: Theme.of(c)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(label,
                style: Theme.of(c)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: DokployTheme.muted))
          ])));
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.borderRadius = 16,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Material(
          color: DokployTheme.panel,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: const BorderSide(color: DokployTheme.border),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

class UpcomingBadge extends StatelessWidget {
  const UpcomingBadge({super.key, this.label = 'Upcoming'});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: DokployTheme.info.withValues(alpha: .11),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: DokployTheme.info.withValues(alpha: .3)),
        ),
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: DokployTheme.info,
            fontSize: 9,
            letterSpacing: .55,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}

class DokployBrandMark extends StatelessWidget {
  const DokployBrandMark({super.key, this.size = 30, this.radius = 8});

  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset(
          'assets/branding/dokploy-mark.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
      );
}

class ProgressMetric extends StatelessWidget {
  const ProgressMetric({
    super.key,
    required this.label,
    required this.value,
    this.available = true,
  });
  final String label;
  final double value;
  final bool available;
  @override
  Widget build(BuildContext c) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label),
          Text(available ? '${value.toStringAsFixed(0)}%' : 'Not available',
              style: const TextStyle(color: DokployTheme.muted))
        ]),
        const SizedBox(height: 8),
        LinearProgressIndicator(
            value: available ? (value / 100).clamp(0, 1) : 0,
            minHeight: 6,
            borderRadius: BorderRadius.circular(99),
            color: available ? _metricColor(value) : DokployTheme.elevated)
      ]);

  Color _metricColor(double value) {
    if (value >= 90) return DokployTheme.danger;
    if (value >= 75) return DokployTheme.warning;
    return DokployTheme.primary;
  }
}
