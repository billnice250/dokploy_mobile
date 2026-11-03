# Dokploy API Notes

The current public API documentation uses `x-api-key` authorization and procedure-style endpoints under `/api`.

Representative verified procedures (reviewed against the public API reference
on 29 October 2026):

```text
GET  /api/project.all
GET  /api/project.one?projectId=...
GET  /api/project.homeStats

GET  /api/application.one?applicationId=...
GET  /api/application.readLogs?applicationId=...&tail=200
POST /api/application.start
POST /api/application.stop
POST /api/application.redeploy
POST /api/application.reload

GET  /api/compose.one?composeId=...
GET  /api/compose.loadServices?composeId=...
GET  /api/compose.getConvertedCompose?composeId=...
POST /api/compose.killBuild

GET  /api/deployment.all?applicationId=...
GET  /api/deployment.allByCompose?composeId=...
GET  /api/deployment.allCentralized
GET  /api/deployment.queueList
GET  /api/deployment.readLogs?deploymentId=...&tail=...
POST /api/deployment.killProcess

GET  /api/schedule.list?id=...&scheduleType=...
GET  /api/domain.byApplicationId?applicationId=...
GET  /api/domain.byComposeId?composeId=...
```

The latest stable Dokploy release checked for this audit is v0.30.10, released
22 October 2026. The public API reference documents four schedule types
(`application`, `compose`, `server`, and `dokploy-server`) and domain reads by
application or Compose service. The mobile adapter treats these optional reads
as capability-gated and tolerates per-target authorization failures. The
upstream v0.30.5 release added Compose deployment with fresh volumes; this
client does not yet expose that destructive option.

The current application log contract documents a tail range of 1–10,000 plus optional `since` and `search` parameters. The mobile adapter clamps tail values and currently filters its already-bounded response locally.

The docs also expose groups for Server, Backup, Schedule, Domain, Postgres, MySQL, MariaDB, Mongo, Redis, Volume Backups, Rollback, Notifications and more. Their presence does not mean their response mapping is implemented; see `IMPLEMENTATION_STATUS.md`.

Before shipping a store release, record actual JSON responses from a disposable test instance and lock them into fixture tests. This is more valuable than assuming response schemas from UI behavior.

## Validated v0.29.14 project shape

On Dokploy v0.29.14, `project.all` returns projects with nested
`environments`, and each environment contains `applications`, `compose`, and
database collections. The repository maps this hierarchy directly; it does not
issue redundant `project.one` requests merely to list services.

## Permission discovery

Dokploy v0.29.14 exposes `GET /api/user.getPermissions`. The real repository
caches this response for the active connection and uses its resource/action
flags to avoid calls that would predictably return 401. A granted server
permission does not activate features whose mobile adapters are unfinished.

## Infrastructure API additions — 3 November 2026

Verified against current official documentation and upstream `canary` source:

- `GET docker.getContainers`: optional `serverId`; returns `containerId`, `name`,
  `image`, `ports`, `state`, and `status`.
- `POST docker.startContainer`, `docker.stopContainer`, `docker.restartContainer`:
  `containerId` and optional `serverId`. Mutations are never retried automatically.
- `GET docker.getServerHealth`: optional `serverId`, `sinceHours=24`; maps only
  resource/count fields into an app-owned diagnostics model. No raw configuration
  or environment secrets are exposed.
- `/terminal`: `serverId` (or `local`), local `username` and `port`, `cols`, `rows`.
- `/docker-container-terminal`: `containerId`, optional `serverId`, `activeWay=sh`,
  `cols`, `rows`. Terminal input is raw text; resize frames use JSON with
  `type=resize`, `cols`, and `rows`. API keys stay in `x-api-key` headers, and
  custom CA/mTLS contexts are reused. A successful upgrade does not itself prove
  shell authorization; server close/error is reflected in the session status.

Sources:
- https://docs.dokploy.com/docs/api/reference-docker
- https://github.com/Dokploy/dokploy/blob/canary/apps/dokploy/server/api/routers/docker.ts
- https://github.com/Dokploy/dokploy/blob/canary/packages/server/src/services/server-health.ts
- https://github.com/Dokploy/dokploy/blob/canary/apps/dokploy/server/wss/terminal.ts
- https://github.com/Dokploy/dokploy/blob/canary/apps/dokploy/server/wss/docker-container-terminal.ts
- https://github.com/Dokploy/dokploy/blob/canary/packages/server/src/lib/auth.ts

This is a selected infrastructure feature expansion, not exhaustive API parity.
Server creation/editing, SSH-key management, destructive container removal,
file management, backups/restores, and other administration APIs remain outside
this implementation.
