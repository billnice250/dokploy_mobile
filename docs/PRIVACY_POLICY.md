# DployGo Privacy Policy

**Last updated:** August 16, 2026

DployGo is an unofficial mobile client for connecting to Dokploy instances that
you or your organization configure. This Privacy Policy explains how DployGo
handles information when you use the app.

In this policy, **“DployGo,” “we,” “us,”** and **“our”** refer to **[DEVELOPER OR
LEGAL ENTITY NAME]**, the developer of the app. **“Dokploy operator”** means the
person or organization that operates a Dokploy instance you connect to. DployGo
is not affiliated with or endorsed by Dokploy.

## Privacy at a glance

- DployGo does not require a DployGo account.
- We do not operate an intermediary server for the app's core functionality.
- Operational requests are sent directly from your device to the Dokploy
  instance you configure.
- API keys are stored on your device using iOS Keychain or Android secure
  storage.
- We do not include advertising or third-party analytics SDKs.
- We do not sell personal information or use it for cross-context behavioral
  advertising.

## Information handled by the app

### Dokploy connection information

When you add an instance, you provide:

- an instance display name;
- the instance's HTTPS URL; and
- a Dokploy API key.

The display name, URL, selected instance identifier, and discovered version
metadata are stored in the app's local preferences. The API key is stored
separately using platform secure storage. DployGo sends the API key directly to
your configured Dokploy instance to authenticate requests. We do not receive or
store the key on developer-operated servers.

### Dokploy operational data

Depending on the features you use and the permissions assigned to your API key,
DployGo may retrieve and display information from your Dokploy instance, such as
projects, services, deployments, logs, server health, domains, schedules,
backups, and database status. The app may also send commands you initiate, such
as starting, stopping, redeploying, or canceling a deployment.

This traffic travels directly between your device and the Dokploy instance you
configured. The Dokploy operator determines how information on that server is
collected, used, secured, and retained. If the instance is operated by your
employer or another organization, contact that organization for its privacy and
data-handling practices.

### Notification information

If you enable deployment alerts, DployGo periodically checks your configured
Dokploy instance while the app is active. It stores notification preferences, a
deployment status snapshot, and up to 100 recent notification events locally on
your device. An event may contain an instance identifier, deployment identifier,
service name, deployment status, timestamp, and a short error message supplied
by your Dokploy instance.

Notifications may appear on your lock screen according to your device settings.
You can disable notification permission or hide notification previews in your
operating system settings. The current version uses local notifications and
does not send this information through a DployGo-operated push-notification
relay.

### Biometric confirmation

DployGo may ask the operating system to confirm your identity with Face ID,
Touch ID, or fingerprint authentication before certain sensitive operations.
Biometric templates remain under the control of the operating system. DployGo
receives only the result of the authentication attempt and does not access,
collect, or store your biometric data.

### Information you send for support

If you contact us, we receive the information you choose to provide, such as
your email address, message, and attachments. Do not send API keys, passwords,
private logs, or other secrets in a support request. We use support information
only to respond, troubleshoot, protect the app, and meet legal obligations.

### App-store and operating-system information

Apple, Google, your device manufacturer, or your operating-system provider may
independently process information about downloads, purchases, crashes, device
performance, or permissions. DployGo does not control those providers' data
practices. Their respective privacy policies apply to their processing.

## How information is used

Information handled by DployGo is used to:

- connect to and authenticate with the Dokploy instance you select;
- display infrastructure and deployment information;
- perform commands you request;
- remember local settings and the active instance;
- provide alerts and notification history when enabled;
- confirm sensitive operations using device security; and
- respond to support requests and protect the app from misuse.

We do not use information from your Dokploy instance for advertising, profiling,
or marketing.

## When information is disclosed

DployGo does not transmit your app data to us. Information may nevertheless be
processed by the following parties when needed for the features you choose:

- **Your Dokploy operator.** Requests, API keys, and operational data are
  exchanged with the instance you configure.
- **Apple or Google and device services.** The operating system provides secure
  storage, biometric confirmation, and local notification functionality. App
  stores may independently process store and diagnostic information.
- **Support or legal service providers.** If you contact us, providers used to
  deliver email or support services may process your message on our behalf.
- **Authorities or transaction participants.** We may disclose information we
  actually possess if required by law, to protect rights and safety, or as part
  of a merger, acquisition, or asset transfer, subject to applicable law.

We do not sell personal information, share it with data brokers, or share it for
cross-context behavioral advertising.

## Storage, retention, and deletion

Most information described in this policy is stored only on your device or on
the Dokploy instance you selected.

- Removing an instance in DployGo deletes its saved profile and API key from the
  device.
- Notification history is limited to the 100 most recent events. In the current
  version, notification history, preferences, and deployment snapshots may
  remain after an instance is removed.
- Clearing DployGo's app data or uninstalling the app removes its local data,
  subject to any device or cloud backups managed by you or your platform
  provider.
- Removing DployGo does not delete information held by a Dokploy instance. Ask
  that instance's operator to access or delete server-side information.


Before uninstalling, remove saved instances in the app if you want their API
keys deleted from platform secure storage immediately. You should also revoke
any DployGo API key in Dokploy when you no longer use it or believe it may have
been compromised.

## Security

DployGo requires HTTPS when adding a real Dokploy instance, stores API keys using
platform secure storage, and does not deliberately place API keys in normal app
logs or error messages. You should use a dedicated, least-privilege Dokploy API
key and keep your device, operating system, and Dokploy server secure.

No storage or transmission method is completely secure. The security of data on
a configured instance also depends on its operator, hosting environment, TLS
configuration, access controls, and Dokploy installation.

## Legal bases for users in the EEA, United Kingdom, or Switzerland

Where applicable data-protection law requires a legal basis, we process the
limited personal data we receive:

- to provide requested app or support functionality and perform a contract;
- with your consent, where we specifically ask for it, such as an optional
  device permission;
- for our legitimate interests in securing, supporting, and improving DployGo,
  where those interests are not overridden by your rights; and
- to comply with legal obligations.

The Dokploy operator may be a separate controller of information stored on its
instance. Contact that operator about its legal bases.

## Your choices and rights

You can:

- choose which Dokploy instance and API key to use;
- remove a saved instance and its API key;
- disable deployment alerts in DployGo;
- deny or revoke notification permission in device settings;
- control notification previews and device backups through platform settings;
- clear the app's storage or uninstall the app; and
- revoke the API key from your Dokploy instance.

Depending on where you live, you may have rights to request access, correction,
deletion, restriction, portability, or objection concerning personal data we
control, and to withdraw consent without affecting earlier lawful processing.
You may also complain to your local data-protection authority. Send requests to
the contact below. We may need to verify your identity before fulfilling a
request.

For information held by a configured Dokploy instance, direct your request to
that instance's operator. We cannot access or delete information on a server we
do not operate.

## Children's privacy

DployGo is an infrastructure administration tool intended for adults and is not
directed to children under 13 or the minimum age required in their jurisdiction.
We do not knowingly collect children's personal information. If you believe a
child has provided personal information to us, contact us so we can take
appropriate action.

## International transfers

Your configured Dokploy instance may be located in another country. You or the
Dokploy operator select that location and are responsible for any resulting
international transfer requirements. Support providers may process support
correspondence in countries other than your own, subject to safeguards required
by applicable law.

## Changes to this policy

We may update this policy when DployGo's features, data practices, or legal
requirements change. We will update the date above and, when required, provide
additional notice in the app or through the app-store listing. Material changes
apply prospectively unless otherwise permitted by law.

## Contact us

**Bill Nice**
**Email:** beta_pearls6g@icloud.com

