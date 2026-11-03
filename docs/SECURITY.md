# Security

## Current guarantees

- Saved API keys, normalized custom CA chains, PKCS#12 client identities, and
  their passwords are written only through `flutter_secure_storage` (Keychain
  on iOS and encrypted platform storage backed by Android security facilities).
- Preferences contain profile identifiers, display names, base URLs, selected
  authentication mode, credential-presence flags, original filenames, and
  discovered version metadata only.
- Real instance enrollment requires HTTPS. Custom trust anchors are scoped to
  one instance and extend the system roots; hostname verification remains
  enabled and the transport does not install a permissive certificate callback.
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

App lock, production-instance policy, screenshot protection, clipboard expiry,
secret reveal flows remain unavailable. UI placeholders
must not be interpreted as security controls.

## Reporting

Before public release, add a private security contact and coordinated disclosure policy here. Do not include API keys, credentials, or unredacted diagnostic bundles in a report.

## Interactive infrastructure access

Real-instance container lifecycle actions require confirmation and biometrics.
Terminal connection requires an explicit Connect action and biometric approval.
Terminal authentication uses the existing instance header and TLS configuration;
SSH private keys remain on the Dokploy host. Terminal text is neither logged nor
persisted and scrollback is limited to 2,000 lines. Backgrounding the app,
changing instances, or closing the screen ends the session. Upstream permission
checks remain authoritative. Demo terminals do not execute commands.
