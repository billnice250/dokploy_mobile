# Optional push relay

The mobile app supports polling today and exposes **Reliable push** as an
explicit, unpaired delivery mode. A small self-hosted relay will be packaged as
a Docker image in a later change.

## Proposed flow

1. Dokploy sends a custom deployment webhook to the relay.
2. The relay verifies a per-installation HMAC signature and rejects replays.
3. The relay maps the opaque installation ID to an APNs or FCM device token.
4. APNs/FCM delivers a notification containing only a title, status and route
   such as `/deployment/abc123`.
5. The app opens the detail route and obtains fresh data directly from Dokploy.

The relay must never receive or store the user's Dokploy API key.

## Minimal relay contract

- `POST /v1/pair`: exchanges a short-lived pairing code for an installation ID.
- `POST /v1/hooks/dokploy/:installationId`: accepts signed Dokploy events.
- `DELETE /v1/pair/:installationId`: revokes a device registration.
- `GET /healthz`: container health check.

Payloads should be small, exclude logs and secrets, expire quickly, and be
deduplicated by deployment ID plus status. Deployment URLs use the app scheme
`dokploy-mobile://app/deployment/:id`; local notifications use the equivalent
GoRouter path `/deployment/:id`.
