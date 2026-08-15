import 'package:go_router/go_router.dart';
import '../screens/shell.dart';
import '../screens/dashboard.dart';
import '../screens/projects.dart';
import '../screens/activity.dart';
import '../screens/servers.dart';
import '../screens/service_detail.dart';
import '../screens/operations.dart';
import '../screens/settings.dart';
import '../screens/deployment_detail.dart';
import '../screens/notifications.dart';
import '../screens/notification_settings.dart';

final router = GoRouter(initialLocation: '/', routes: [
  StatefulShellRoute.indexedStack(
    builder: (context, state, navigationShell) =>
        AppShell(navigationShell: navigationShell),
    branches: [
      StatefulShellBranch(routes: [
        GoRoute(path: '/', builder: (c, s) => const DashboardScreen())
      ]),
      StatefulShellBranch(routes: [
        GoRoute(path: '/projects', builder: (c, s) => const ProjectsScreen())
      ]),
      StatefulShellBranch(routes: [
        GoRoute(path: '/activity', builder: (c, s) => const ActivityScreen())
      ]),
      StatefulShellBranch(routes: [
        GoRoute(path: '/servers', builder: (c, s) => const ServersScreen())
      ]),
    ],
  ),
  GoRoute(
      path: '/service/:id',
      builder: (c, s) =>
          ServiceDetailScreen(serviceId: s.pathParameters['id']!)),
  GoRoute(
      path: '/deployment/:id',
      builder: (c, s) => DeploymentDetailScreen(
            deploymentId: s.pathParameters['id']!,
          )),
  GoRoute(path: '/operations', builder: (c, s) => const OperationsScreen()),
  GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
  GoRoute(
      path: '/notifications', builder: (c, s) => const NotificationsScreen()),
  GoRoute(
      path: '/notification-settings',
      builder: (c, s) => const NotificationSettingsScreen()),
]);
