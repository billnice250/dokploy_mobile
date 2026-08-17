# Store release setup

The Android workflow at `.github/workflows/android_play.yml` tests, builds,
signs, and uploads an Android App Bundle to Google Play:

- A push to `main` creates a draft release on the internal track.
- A manual run accepts `internal`, `alpha` (closed testing), `beta` (open
  testing), or `production`.
- Publishing a GitHub release creates a draft production-track release.

Google authentication uses GitHub OIDC and Workload Identity Federation. It
does not use a long-lived Google service-account JSON key.

Before installing Flutter or building the app, the workflow obtains a
short-lived access token, creates a temporary Google Play edit, and immediately
deletes it. A provider, impersonation, API, app-record, or Play permission error
therefore fails quickly without spending time on a build. The workflow
authenticates again immediately before the real upload.

## Stable application identifiers

- iOS bundle ID: `it.billnice.apps.dokploy`
- Android application ID: `it.billnice.apps.dokploy`

Do not change these identifiers after the first store upload.

## Google Cloud Workload Identity Federation

The workflow uses these existing Google Cloud resources:

- Project: `bill-apps-ci-build`
- Project number: `96345954330`
- Pool: `github`
- Provider: `github-provider`
- Service account:
  `moneytone@bill-apps-ci-build.iam.gserviceaccount.com`

Add their identifiers under **GitHub → Settings → Secrets and variables →
Actions → Variables**:

| Repository variable | Value |
| --- | --- |
| `GCP_PROJECT_ID` | `bill-apps-ci-build` |
| `GCP_WIF_PROVIDER` | `projects/96345954330/locations/global/workloadIdentityPools/github/providers/github-provider` |
| `GCP_SERVICE_ACCOUNT` | `moneytone@bill-apps-ci-build.iam.gserviceaccount.com` |

These are resource identifiers, not credentials. Repository variables keep
deployment configuration out of the workflow while encrypted secrets remain
reserved for keystores, passwords, tokens, and private keys. The workflow
checks that all three variables exist before attempting authentication.

The provider must admit this repository’s `main` branch and release tags.
Inspect the live provider before changing it:

```bash
gcloud iam workload-identity-pools providers describe github-provider \
  --project=bill-apps-ci-build \
  --location=global \
  --workload-identity-pool=github \
  --format='yaml(attributeMapping,attributeCondition)'
```

Apply the repository-scoped mapping and condition:

```bash
gcloud iam workload-identity-pools providers update-oidc github-provider \
  --project=bill-apps-ci-build \
  --location=global \
  --workload-identity-pool=github \
  --attribute-mapping='google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner,attribute.ref=assertion.ref' \
  --attribute-condition="assertion.repository_owner == 'billnice250' && assertion.repository == 'billnice250/dokploy_mobile' && (assertion.ref == 'refs/heads/main' || assertion.ref.startsWith('refs/tags/'))"
```

Allow only this repository to impersonate the upload service account:

```bash
gcloud iam service-accounts add-iam-policy-binding \
  moneytone@bill-apps-ci-build.iam.gserviceaccount.com \
  --project=bill-apps-ci-build \
  --role=roles/iam.workloadIdentityUser \
  --member='principalSet://iam.googleapis.com/projects/96345954330/locations/global/workloadIdentityPools/github/attribute.repository/billnice250/dokploy_mobile'
```

Google IAM changes can take several minutes to propagate. The workflow error
`The given credential is rejected by the attribute condition` means the first
provider condition did not match the GitHub OIDC token. An error generating an
OAuth access token instead points to the service-account IAM binding.

## Google Play preparation

1. Create the app in Play Console using `it.billnice.apps.dokploy`.
2. Create the upload keystore and enroll it in Play App Signing.
3. Enable the Google Play Android Developer API.
4. In Play Console, invite
   `moneytone@bill-apps-ci-build.iam.gserviceaccount.com` and grant only the
   release permissions needed for this app.
5. Add these GitHub Actions secrets:

   - `ANDROID_KEYSTORE_BASE64`
   - `ANDROID_KEYSTORE_PASSWORD`
   - `ANDROID_KEY_ALIAS`
   - `ANDROID_KEY_PASSWORD` (optional when it matches the store password)

Generate the upload keystore and set all four secrets directly with the GitHub
CLI:

```bash
./scripts/generate_android_signing_secrets.sh --set-github
```

The command requires an authenticated `gh` CLI. To enter the values manually
in GitHub instead, explicitly print them:

```bash
./scripts/generate_android_signing_secrets.sh --print
```

Printed values are sensitive. The generated `android/keystore.p12` is ignored
by Git. Direct GitHub setup also creates the Git-ignored, permission-restricted
`android/signing-secrets.env.secret`, because GitHub secrets cannot be read
back. Back up the keystore and recovery values in a secure location, then
remove the local recovery file. Losing the upload key or password can prevent
future app updates.

The workflow writes temporary `android/key.properties` and
`android/keystore.p12` files on the GitHub runner. Both paths are ignored by
Git and the runner is discarded after the job.

Fastlane `2.233.1` or newer is required because the Play uploader uses the
Application Default Credentials file exported by
`google-github-actions/auth`.

## Run an Android release

For a manual upload:

1. Open **Actions → Android → Play Console**.
2. Select **Run workflow**.
3. Choose the Play track.
4. Optionally enter a positive integer `versionCode`.

When no build number is supplied, the workflow uses
`20 + github.run_number`. Uploads are drafts and still require review or
promotion in Play Console.

## App Store Connect preparation

The repository contains an iOS Fastlane `beta` lane, but no automated iOS
GitHub Actions workflow yet. To prepare a future TestFlight upload:

1. Register `it.billnice.apps.dokploy` in the Apple Developer portal.
2. Create the **DployGo** record in App Store Connect.
3. Create an App Store distribution certificate and provisioning profile.
4. Create an App Store Connect API key that can upload builds.
5. Provide these values to the release environment:

   - `APP_STORE_CONNECT_KEY_ID`
   - `APP_STORE_CONNECT_ISSUER_ID`
   - `APP_STORE_CONNECT_KEY_BASE64`
   - `IOS_IPA_PATH`

Upload an already signed IPA with:

```bash
bundle exec fastlane ios beta
```

Before any public release, complete privacy disclosures, screenshots,
descriptions, support and privacy URLs, content rating, export compliance, and
review notes. DployGo is unofficial, so every listing must state that clearly.
