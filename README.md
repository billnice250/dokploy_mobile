# DployGo

An **unofficial Flutter mobile console for Dokploy**, designed for operations from a phone rather than as a pixel-for-pixel port of the web dashboard.

> Status: v0.1 foundation. The project contains a polished demo mode, a real Dokploy transport/repository layer, secure multi-instance storage, and an initial operational slice. Advanced modules remain unavailable until their current response models are validated. See [Implementation Status](docs/IMPLEMENTATION_STATUS.md) for the exact real/demo boundary.

## What is included

- Multi-instance architecture with API key and mutual-TLS authentication
- Secure API key, custom CA, and PKCS#12 client-identity storage
- Dokploy-like dark UI and mobile command center
- Projects and service browsing
- Application / Compose / database service model
- Start, stop, redeploy and cancel-deployment operations
- Application logs and deployment activity
- Server health cards and CPU/memory/disk views
- Compose-oriented service UX
- Backup center UI
- Scheduled jobs UI
- Domain/routing UI
- Database operations surface
- Terminal capability placeholder (terminal and biometric gates are not implemented)
- Notification, widget and Shortcut roadmap hooks
- Compatibility adapter boundary and demo repository
- Tests and documentation

## Architecture

```text
Flutter UI
   │
   ├── Riverpod providers
   │
   ▼
DokployRepository  ← stable domain contract
   │
   ├── MockDokployRepository (demo / screenshots / development)
   └── RealDokployRepository
             │
             ▼
        DokployApi
        /api/project.all
        /api/application.*
        /api/compose.*
        /api/deployment.*
        ...
```

The UI never knows Dokploy procedure names. That is deliberate: Dokploy's HTTP API is RPC-like and currently uses unversioned paths. All upstream coupling stays in `lib/data/dokploy_api.dart` and `lib/data/real_repository.dart`.

## Current API assumptions

Verified against the public Dokploy API documentation in August 2026:

- Authentication: `x-api-key`
- `project.all`, `project.one`, `project.homeStats`
- `application.one`, `application.start`, `application.stop`, `application.redeploy`, `application.reload`, `application.readLogs`
- `compose.one`, `compose.loadServices`, Compose lifecycle procedures
- `deployment.all`, `deployment.allByCompose`, `deployment.allCentralized`, `deployment.queueList`, `deployment.readLogs`, `deployment.killProcess`
- server, schedule, backup, domain and database API groups exist in the public API surface

Because the API is not URL-versioned, use capability detection and keep compatibility fixes inside the adapter.

## Getting started

This ZIP is source-first and intentionally does not vendor Flutter SDK/platform-generated build artifacts.

1. Install FVM and make Flutter `3.44.1` available (`fvm install`).
2. From this directory run:

```bash
fvm flutter create . --platforms=android,ios
fvm flutter pub get
fvm flutter run
```

Always run Flutter and Dart through FVM in this repository. Plain `flutter`
uses whichever SDK is globally first on `PATH` and does not apply `.fvmrc`.
Check the project SDK with `fvm flutter --version`; change the project pin with
`fvm use <version>`, not `flutter use`.

The app launches in **Demo Infrastructure** mode, so you can inspect the UI without a Dokploy server.

### Connecting a real server

1. In Dokploy, create an API token that has only the permissions you want the phone to have.
2. Open **Settings → Add Dokploy instance**.
3. Enter the HTTPS URL and token. If required, add one or more PEM/P7B CA
   chains and a password-protected `.p12`/`.pfx` client identity.
4. Tap **Test & save**. The app probes `project.all`, stores the key securely, and switches to the real repository.

Saved profiles can be switched or removed in Settings, and the last active real instance is restored at startup.

## Security model

- Never put API keys, CA chains, client identities, or certificate passwords in
  SharedPreferences, logs, analytics, or crash reports.
- Keep secrets in Keychain/Keystore only.
- Require valid HTTPS by default.
- Prefer a dedicated least-privilege Dokploy API token for mobile use.
- Require biometrics for terminal, database password changes, deletion and other privileged/destructive actions.
- Add a second confirmation for delete-volume / delete-database operations.
- Optional push relays should receive Dokploy webhook events, **not** the Dokploy API key.

## Suggested project layout

```text
lib/
  core/       theme, navigation, providers, common widgets
  data/       transport, compatibility adapter, repository, secure store
  domain/     app-owned models
  screens/    mobile feature surfaces
```

## Roadmap

### v0.1 — Mobile operations foundation

- [X] Dokploy-style mobile shell
- [X] Demo mode
- [X] Multi-instance domain model
- [X] Secure credential store
- [X] Dashboard
- [X] Projects/services
- [X] Service details
- [X] Logs
- [X] Deployments/queue with detail and bounded build logs
- [X] Start/stop/redeploy/cancel transport operations
- [X] Servers UI
- [X] Backups / schedules / domains / databases surfaces
- [X] Add Instance → connectivity probe → secure save → live repository wiring
- [ ] Validate DTOs against a real current Dokploy instance
- [X] Permission-based capability gating via `user.getPermissions`
- [ ] Version/endpoint compatibility matrix

### v0.2 — Full operational parity

- [ ] Compose per-service logs and metrics
- [ ] Database lifecycle for Postgres/MySQL/MariaDB/Mongo/Redis
- [ ] Trigger/restore backups
- [ ] Named-volume backups
- [ ] Scheduled-job create/edit/run-now/history
- [ ] Domain create/edit/delete and TLS state
- [ ] Deployment rollback and preview deployments
- [ ] Environment/config editors with secret masking
- [ ] Mounts, ports and registry views
- [ ] Pull-to-refresh everywhere + cached last-known state

### v0.3 — Mobile-native power features

- [ ] Push notifications from Dokploy webhooks
- [ ] Notification deep links to failed log lines
- [ ] Biometric-protected terminal
- [ ] iOS/Android home-screen widgets
- [ ] Siri Shortcuts / Android App Actions
- [ ] “Backup then redeploy” workflow
- [ ] Deployment before/after comparison
- [ ] GitHub/GitLab commit context
- [ ] Offline read-only cache

### v1.0 — Hardened client

- [ ] Automated compatibility tests against multiple Dokploy releases
- [ ] Tested version/capability matrix in-app
- [ ] Crash-safe secret redaction
- [ ] Accessibility + tablet layouts
- [ ] Localization
- [ ] App Store / Play Store packaging and privacy documentation

## Compatibility strategy

Do **not** force users to pin Dokploy. Instead:

1. Detect the server/version/capabilities where possible.
2. Maintain stable app-owned domain models.
3. Map Dokploy DTOs at the repository boundary.
4. Hide unsupported features gracefully.
5. Test `latest` plus selected older Dokploy releases in CI.
6. Warn on an untested newer release but allow read-only/known operations to continue.

## CI idea

Run integration tests against containerized Dokploy versions and publish a matrix:

```text
Dokploy 0.xx.y   45/45 ✅
Dokploy 0.xy.z   44/45 ⚠️ compose logs changed
latest           45/45 ✅
```

## Licensing / trademark

This project is an unofficial client. Before publishing publicly, choose your own project name/icon and add the appropriate attribution/trademark language instead of implying it is an official Dokploy product.
