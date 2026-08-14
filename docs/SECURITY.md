# Security

## Current guarantees

- A saved API key is written only through `flutter_secure_storage` (Keychain on iOS and encrypted platform storage backed by Android security facilities).
- Preferences contain profile identifiers, display names, base URLs, and discovered version metadata only.
- Real instance enrollment requires HTTPS. The transport does not install a permissive certificate callback.
- API keys are never added to error text, domain objects, or UI state.
- Debug HTTP tracing redacts credentials and sensitive response fields. API
  keys are represented only by their trimmed length and a 12-character SHA-256
  fingerprint so developers can verify which key was sent without exposing it.
- Mutating POST requests are not automatically retried.
- Stop and deployment-cancel actions require confirmation.
- Log requests use bounded tail counts.

## Token guidance

Use a dedicated, least-privilege Dokploy token. Dokploy permissions can limit API/CLI and project access; a mobile token should receive only the operations the user needs.

## Not implemented yet

Biometric gates, app lock, production-instance policy, screenshot protection, clipboard expiry, terminal sessions, and secret reveal flows remain unavailable. UI placeholders must not be interpreted as security controls.

## Reporting

Before public release, add a private security contact and coordinated disclosure policy here. Do not include API keys, credentials, or unredacted diagnostic bundles in a report.
