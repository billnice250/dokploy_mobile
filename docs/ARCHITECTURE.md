# Architecture

## Goals

1. Keep Dokploy API drift isolated.
2. Make every destructive operation explicit and auditable.
3. Make the app useful in demo/offline mode.
4. Support multiple Dokploy instances from day one.

## Layers

**Transport (`DokployApi`)** knows HTTP and procedure names. **Repository** maps unstable upstream DTOs into stable app-owned domain models. **Providers** expose state. **Screens** only use repository/domain contracts.

## Compatibility

Dokploy currently exposes an RPC-like unversioned `/api/<group>.<procedure>` surface. Treat each API group as a capability. Unknown fields are ignored; missing optional fields get safe fallbacks. Avoid passing raw response maps into UI widgets.

## Destructive actions

Classify operations into:

- Safe: logs, status, metrics, start, restart/redeploy.
- Confirm: stop, cancel deployment, config changes.
- Biometric + confirm: delete service/database/volume, password changes, terminal, server-level administration.

## Push notifications

Preferred design:

```text
Dokploy webhook → tiny stateless relay → APNs/FCM → app deep link
```

The relay should never receive or store the Dokploy API key.
