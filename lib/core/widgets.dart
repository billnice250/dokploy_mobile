import 'package:flutter/material.dart';
import '../domain/models.dart';
import 'theme.dart';

Color statusColor(HealthState s) => switch (s) {
      HealthState.healthy => DokployTheme.success,
      HealthState.warning => DokployTheme.warning,
      HealthState.failed => DokployTheme.danger,
      HealthState.stopped => DokployTheme.muted,
      HealthState.deploying => DokployTheme.purple,
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

class ProgressMetric extends StatelessWidget {
  const ProgressMetric({super.key, required this.label, required this.value});
  final String label;
  final double value;
  @override
  Widget build(BuildContext c) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label),
          Text('${value.toStringAsFixed(0)}%',
              style: const TextStyle(color: DokployTheme.muted))
        ]),
        const SizedBox(height: 8),
        LinearProgressIndicator(
            value: (value / 100).clamp(0, 1),
            minHeight: 6,
            borderRadius: BorderRadius.circular(99))
      ]);
}
