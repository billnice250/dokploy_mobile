# Store release setup

The manual GitHub Actions workflow `.github/workflows/store-release.yml` builds,
tests and uploads a draft Android internal-testing release and/or an iOS
TestFlight build. It cannot publish until the store records, signing assets and
repository secrets below exist.

## Stable application identifiers

- iOS bundle ID: `it.billnice.dokployMobile`
- Android application ID: `it.billnice.dokploymobile`

These identifiers should not be changed after the first store upload.

## App Store Connect preparation

1. Register the bundle ID in the Apple Developer portal.
2. Create the **Dokploy Mobile** app record in App Store Connect.
3. Create an App Store distribution certificate and provisioning profile.
4. Create an App Store Connect API key with permission to upload builds.
5. Add these GitHub Actions secrets:

   - `IOS_DISTRIBUTION_CERTIFICATE_BASE64`
   - `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD`
   - `IOS_PROVISIONING_PROFILE_BASE64`
   - `IOS_PROVISIONING_PROFILE_NAME`
   - `APP_STORE_CONNECT_KEY_ID`
   - `APP_STORE_CONNECT_ISSUER_ID`
   - `APP_STORE_CONNECT_KEY_BASE64`

The certificate, profile and `.p8` key values are base64-encoded file contents.

## Google Play preparation

1. Create the app in Play Console using `it.billnice.dokploymobile`.
2. Create the upload keystore and enroll it in Play App Signing.
3. Enable the Google Play Developer API and grant a service account release
   access to this app.
4. Add these GitHub Actions secrets:

   - `ANDROID_KEYSTORE_BASE64`
   - `ANDROID_KEYSTORE_PASSWORD`
   - `ANDROID_KEY_ALIAS`
   - `ANDROID_KEY_PASSWORD`
   - `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`

## Releasing

Open **Actions → Store release → Run workflow**, then choose `android`, `ios`
or `both`. Google Play uploads are created as drafts on the internal track;
TestFlight uploads do not automatically submit the app for App Review.

Before public release, complete privacy disclosures, screenshots, descriptions,
support/privacy URLs, content rating, export compliance and platform review
notes. Dokploy Mobile is unofficial, so its listing should state that clearly.
