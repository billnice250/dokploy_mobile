# Implementation Status

Last audited: 14 August 2026.

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
- List centralized deployments and request deployment cancellation.
- List servers when the token has access. Server inventory is capability-gated;
  Dokploy 401/403 responses for `server.all` do not break project or deployment
  views authenticated by the same otherwise-valid token.
- Map HTTP, connectivity, timeout, and TLS failures into app-owned failure categories.

These paths use the real `DokployApi` through `RealDokployRepository`; widgets do not call Dio.

## Demo-only

- Rich dashboard health and attention data.
- Server CPU, memory, and disk percentages.
- Backup center data.
- Scheduled-job data.
- Domain data.
- Database summary data.
- Detailed service CPU, memory, and network values.

The real repository returns empty backup, schedule, and domain collections until their current response contracts have fixture coverage.

## Partial

- Project hierarchy: projects and services work, but environments are not yet first-class domain objects or navigation levels.
- Compose: stack lifecycle exists, but per-service status, metrics, and logs are not mapped.
- Deployments: centralized history is mapped defensively; stage tracking and deployment-log navigation are not implemented.
- Logs: bounded loading, filtering, tail selection, refresh, selection, long-press copy, and warning/error color are present. Live streaming, pause/resume, ranges, and export are not.
- Servers: listing is real, but metrics are only displayed when compatible values are present in the list response.
- Capabilities: `user.getPermissions` is cached per active connection and gates
  optional reads and actions. Version discovery and endpoint-level compatibility
  probing beyond that permission map are not implemented.

## Planned / unavailable

- Real backups, schedules, domains, and full database management.
- Compose service inspection and terminal sessions.
- Biometrics, app lock, screenshot protection, and clipboard auto-clear.
- Push relay, home-screen widgets, shortcuts, and Git enrichment.
- Compatibility CI against disposable Dokploy versions.
- Aggregated All Instances dashboard.

## Current verification

- `dart format`: enforced on `lib/` and `test/`.
- `flutter analyze`: clean.
- `flutter test`: unit and widget coverage exists for demo startup and transport failure mapping.
- Android/iOS folders exist. Platform debug builds are part of the release verification checklist.
