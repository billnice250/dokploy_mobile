# Dokploy API Notes

The current public API documentation uses `x-api-key` authorization and procedure-style endpoints under `/api`.

Representative verified procedures (August 2026):

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
POST /api/compose.killBuild

GET  /api/deployment.all?applicationId=...
GET  /api/deployment.allByCompose?composeId=...
GET  /api/deployment.allCentralized
GET  /api/deployment.queueList
GET  /api/deployment.readLogs?deploymentId=...&tail=...
POST /api/deployment.killProcess
```

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
