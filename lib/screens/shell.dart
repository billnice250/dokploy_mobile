import 'dart:ui';

import 'package:flutter/material.dart';
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
                        color: const Color(0xD9202024),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .14),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: .42),
                            blurRadius: 28,
                            offset: const Offset(0, 12),
                          ),
                          BoxShadow(
                            color: Colors.white.withValues(alpha: .035),
                            blurRadius: 8,
                            offset: const Offset(0, -1),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          for (var index = 0;
                              index < _destinations.length;
                              index++)
                            Expanded(
                              child: _GlassDestination(
                                icon: _destinations[index].$1,
                                selectedIcon: _destinations[index].$2,
                                label: _destinations[index].$3,
                                selected: navigationShell.currentIndex == index,
                                onTap: () => navigationShell.goBranch(
                                  index,
                                  initialLocation:
                                      index == navigationShell.currentIndex,
                                ),
                              ),
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
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Tooltip(
          message: label,
          child: InkWell(
            borderRadius: BorderRadius.circular(21),
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: .13)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(21),
                border: Border.all(
                  color: selected
                      ? Colors.white.withValues(alpha: .11)
                      : Colors.transparent,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      selected ? selectedIcon : icon,
                      key: ValueKey(selected),
                      size: 21,
                      color:
                          selected ? DokployTheme.primary : DokployTheme.muted,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color:
                          selected ? DokployTheme.primary : DokployTheme.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
