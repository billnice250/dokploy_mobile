# Implementation Status

Last audited: 29 October 2026.

This document describes the code that exists today. It deliberately does not count a screen placeholder as a working feature.

## Working with the real API

- Add a Dokploy instance over HTTPS and validate its API key with `project.all`.
- Store API keys in platform secure storage and non-secret profile metadata in preferences.
- Restore the last active real instance at app startup.
- List, switch, and remove saved instances; demo mode remains available.
- Load projects and map project environments into application and Compose summaries.
- Load application logs with a bounded tail count.
- Start, stop, and redeploy applications.
- Start, stop, and deploy Compose stacks.
- List centralized deployments, open deployment detail, read bounded build
  logs, and request deployment cancellation.
- List servers when the token has access. Server inventory is capability-gated;
  Dokploy 401/403 responses for `server.all` do not break project or deployment
  views authenticated by the same otherwise-valid token.
- Map HTTP, connectivity, timeout, and TLS failures into app-owned failure categories.
- Maintain a per-instance notification center, poll deployment transitions while
  the app is active, apply quiet hours/event rules, and open deployment deep
  links from local notifications.

These paths use the real `DokployApi` through `RealDokployRepository`; widgets do not call Dio.

## Demo-only

- Rich dashboard health and attention data.
- Server CPU, memory, and disk percentages.
- Backup center data.
- Detailed service CPU, memory, and network values.

The real repository still returns an empty backup collection pending
response fixtures. Schedule and domain reads are implemented below.

## Partial

- Project hierarchy: projects and services work, but environments are not yet first-class domain objects or navigation levels.
- Compose: stack lifecycle and rendered Compose preview work. Per-service
  status, metrics, and logs are not mapped.
- Databases: PostgreSQL, MySQL, MariaDB, MongoDB, and Redis appear in a
  dedicated list. Nonsecret settings, logs, and start/stop/deploy operations
  are mapped. Backup/restore, database shell, password management, and create
  or delete flows are not implemented.
- Deployments: centralized history, timestamps, duration, failure context, and
  deployment-log navigation are mapped defensively. Active logs support
  pause/resume polling, search, bounded tail selection, and copy. Distinct build
  stages are not inferred because Dokploy does not expose them reliably.
- Logs: bounded loading, filtering, tail selection, refresh, selection, long-press copy, and warning/error color are present. Live streaming, pause/resume, ranges, and export are not.
- Servers: inventory is enriched with the latest `server.getServerMetrics`
  sample for configured remote servers. The Dokploy control-plane monitoring
  configuration is also detected through `user.getMetricsToken`. Missing or
  unconfigured telemetry is shown as unavailable instead of a false `0%`.
  Metric parsing accepts wrapped responses and formatted percentages, and shows
  total/used/free storage when `totalDisk` is returned. Owners can configure
  monitoring and run the confirmed `settings.cleanDockerPrune` cleanup from the
  server card.
- Capabilities: `user.getPermissions` is cached per active connection and gates
  optional reads and actions. Version discovery and endpoint-level compatibility
  probing beyond that permission map are not implemented.
- Notifications: foreground polling and local alerts work. Reliable background
  delivery is modeled in preferences but remains unpaired until the optional
  webhook-to-APNs/FCM relay is packaged.
- Schedules and domains: read-only lists use Dokploy's documented
  `schedule.list`, `domain.byApplicationId`, and `domain.byComposeId` calls.
  Writes, run history, and domain editing remain unavailable pending fixtures
  from supported Dokploy versions.
- Home-screen widget: Android and iOS widgets show the active instance name and
  running/stopped/failed counts from the latest dashboard load. The widget
  receives no credentials and does not make server requests; app-group signing
  must be enabled for iOS distribution.

## Planned / unavailable

- Real backups and full database management, including create/delete,
  password management, and restore workflows.
- Schedule creation/editing/run history and domain creation/editing.
- Compose service inspection and terminal sessions.
- Biometrics, app lock, screenshot protection, and clipboard auto-clear.
- Shortcut actions, push relay image, and Git enrichment.
- Compatibility CI against disposable Dokploy versions.
- Aggregated All Instances dashboard.

## Current verification

- `dart format`: enforced on `lib/` and `test/`.
- `flutter analyze`: clean for the last audited change set.
- `flutter test`: unit and widget coverage includes demo startup, transport
  failure mapping, deployment transition alerts, and overnight quiet hours.
- Android debug APK and iOS simulator builds pass with the notification plugin.
- Native launcher icons and dark splash screens are generated from the shared
  DployGo brand mark.
- A manual, draft-only GitHub Actions release workflow is scaffolded for Google
  Play internal testing and TestFlight. Store records, signing material and
  repository secrets are still required before it can upload.
