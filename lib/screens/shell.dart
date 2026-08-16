import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    (Icons.dashboard_outlined, Icons.dashboard_rounded, 'Home'),
    (Icons.folder_outlined, Icons.folder_rounded, 'Projects'),
    (Icons.bolt_outlined, Icons.bolt_rounded, 'Activity'),
    (Icons.dns_outlined, Icons.dns_rounded, 'Servers'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            navigationShell,
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: SafeArea(
                top: false,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: Container(
                      height: 68,
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color:
                            DokployTheme.panelOf(context).withValues(alpha: .9),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: DokployTheme.borderOf(context),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? .42
                                  : .14,
                            ),
                            blurRadius: 28,
                            offset: const Offset(0, 12),
                          ),
                          BoxShadow(
                            color: Colors.white.withValues(alpha: .12),
                            blurRadius: 8,
                            offset: const Offset(0, -1),
                          ),
                        ],
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          AnimatedAlign(
                            key: const ValueKey('liquid-nav-indicator'),
                            alignment: Alignment(
                              -1 +
                                  (2 *
                                      navigationShell.currentIndex /
                                      (_destinations.length - 1)),
                              0,
                            ),
                            duration: MediaQuery.maybeOf(context)
                                        ?.disableAnimations ==
                                    true
                                ? Duration.zero
                                : const Duration(milliseconds: 430),
                            curve: const Cubic(.22, 1, .36, 1),
                            child: const FractionallySizedBox(
                              widthFactor: 1 / 4,
                              heightFactor: 1,
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 2),
                                child: _LiquidGlassLens(),
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              for (var index = 0;
                                  index < _destinations.length;
                                  index++)
                                Expanded(
                                  child: _GlassDestination(
                                    icon: _destinations[index].$1,
                                    selectedIcon: _destinations[index].$2,
                                    label: _destinations[index].$3,
                                    selected:
                                        navigationShell.currentIndex == index,
                                    onTap: () => navigationShell.goBranch(
                                      index,
                                      initialLocation:
                                          index == navigationShell.currentIndex,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

class _LiquidGlassLens extends StatelessWidget {
  const _LiquidGlassLens();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = DokployTheme.foregroundOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(21),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? [
                      Colors.white.withValues(alpha: .18),
                      Colors.white.withValues(alpha: .07),
                    ]
                  : [
                      Colors.white.withValues(alpha: .86),
                      foreground.withValues(alpha: .08),
                    ],
            ),
            borderRadius: BorderRadius.circular(21),
            border: Border.all(
              color: Colors.white.withValues(alpha: dark ? .2 : .8),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? .28 : .12),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: dark ? .08 : .7),
                blurRadius: 5,
                offset: const Offset(0, -1),
              ),
            ],
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 13),
              color: Colors.white.withValues(alpha: dark ? .35 : .95),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassDestination extends StatelessWidget {
  const _GlassDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final foreground = DokployTheme.foregroundOf(context);
    final muted = DokployTheme.mutedOf(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Tooltip(
        message: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(21),
          onTap: () {
            if (!selected) HapticFeedback.selectionClick();
            onTap();
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: disableAnimations
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                child: AnimatedScale(
                  scale: selected ? 1.1 : 1,
                  duration: disableAnimations
                      ? Duration.zero
                      : const Duration(milliseconds: 260),
                  curve: Curves.easeOutBack,
                  child: Icon(
                    selected ? selectedIcon : icon,
                    key: ValueKey(selected),
                    size: 21,
                    color: selected ? foreground : muted,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? foreground : muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AnimatedBranchContainer extends StatelessWidget {
  const AnimatedBranchContainer({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  final int currentIndex;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var index = 0; index < children.length; index++)
          IgnorePointer(
            ignoring: index != currentIndex,
            child: ExcludeSemantics(
              excluding: index != currentIndex,
              // Keep the opacity ticker outside TickerMode. Otherwise an
              // outgoing branch is paused before it can become transparent
              // and can leave the last (Servers) scaffold painted on top.
              child: AnimatedOpacity(
                key: ValueKey('branch-opacity-$index'),
                opacity: index == currentIndex ? 1 : 0,
                duration: disableAnimations
                    ? Duration.zero
                    : const Duration(milliseconds: 230),
                curve: Curves.easeOutCubic,
                child: TickerMode(
                  enabled: index == currentIndex,
                  child: children[index],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
