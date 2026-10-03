# ADR-013: Android application ID and release signing

## Status

Accepted

## Context

The Flutter client (`apps/client`) must be published to Google Play under the
package `com.nd.chtohochu`. During package registration, Google Play Console
required an upload key certificate fingerprint (SHA-256) to complete enrollment
of `com.nd.chtohochu`.

Two problems were found during the signing audit:

1. **Application ID mismatch.** `apps/client/android/app/build.gradle.kts`
   declared `applicationId = "ru.nd.chtohochu"`, while Google Play Console
   expected `com.nd.chtohochu`. Google Play rejects App Bundles whose
   `applicationId` does not match the registered package. The `namespace`
   (which determines the R-class package and the Kotlin source path) was
   `ru.nd.chtohochu` and is intentionally left unchanged — `namespace` and
   `applicationId` are independent and `namespace` has no effect on store
   identity.

2. **No release signing configuration.** The `release` build type was signed
   with the debug keystore (`~/.android/debug.keystore`, alias
   `AndroidDebugKey`, `CN=Android Debug`, well-known password `android`). This
   is the Flutter template placeholder and is unacceptable for production:
   the debug certificate is publicly recognizable, the password is public, and
   Google Play does not accept debug-signed bundles. No release/upload
   keystore, `key.properties`, or `signingConfigs.release` block existed in the
   project.

AGENTS.md §16 (Security Rules) requires HTTPS everywhere, secrets in
environment variables only, and no production credentials committed. AGENTS.md
§23 requires documenting architectural decisions in an ADR rather than
silently changing them.

## Decision

### Application ID

Set the Android `applicationId` to `com.nd.chtohochu`, matching the Google Play
package. The Gradle `namespace` remains `ru.nd.chtohochu` (R-class package and
Kotlin source path); it does not affect store identity and changing it would
require moving source files with no benefit.

`google-services.json` `package_name` is updated to `com.nd.chtohochu` so the
`google-services` Gradle plugin matches `applicationId` at build time. The
Firebase project (`chtohochu-47574`) must register `com.nd.chtohochu` as an
Android app and a fresh `google-services.json` must replace the hand-edited
file. This is tracked as a follow-up, not part of this ADR's code change.

### Release signing

Establish a dedicated upload keystore and a `signingConfigs.release` block:

- **Keystore:** `apps/client/android/app/chtohochu-upload.jks` (JKS, 4096-bit
  RSA, `SHA384withRSA`, valid 30 years, alias `chtohochu`,
  `CN=ChtoHochu, O=ND, C=RU`).
- **Credentials:** `apps/client/android/key.properties` (git-ignored) holds
  `storePassword`, `keyPassword`, `keyAlias`, `storeFile`. Passwords are
  randomly generated and stored only in `key.properties`, never committed.
- **Gradle wiring:** `build.gradle.kts` loads `key.properties` and defines
  `signingConfigs.release`; the `release` build type uses
  `signingConfigs.getByName("release")` instead of the debug config.
- **Debug/profile builds** continue to use the debug keystore unchanged.

### Google Play App Signing

Enroll in Google Play App Signing. The local upload key (`chtohochu-upload.jks`)
signs App Bundles uploaded to Play Console. Google Play re-signs the delivered
APKs with its own app signing key. The upload key certificate SHA-256 is
registered in Play Console during package enrollment. This keeps the upload
key revocable (via Play Console support) without losing the app's store listing.

## Consequences

**Positive**

- **Store identity correct.** `applicationId` matches the Google Play package,
  so App Bundles are accepted.
- **Production-grade signing.** A dedicated 4096-bit RSA upload key replaces
  the debug placeholder; bundles are signed with a private, non-public
  certificate.
- **Secret hygiene.** Keystore and passwords live in git-ignored files; no
  secrets enter the repository. `.gitignore` already covers `key.properties`,
  `*.jks`, and `*.keystore`.
- **App Signing enrolled.** Google Play holds the app signing key; a lost or
  compromised upload key can be reset through Play Console support without
  losing the application listing.

**Negative**

- **Key custody burden.** The upload keystore and `key.properties` must be
  backed up outside the repository. Loss requires a support ticket to Google
  Play to reset the upload key. Mitigated by storing backups in a secure
  location (password manager / offline storage).
- **Firebase follow-up.** `google-services.json` was hand-edited to match the
  new `applicationId`; it must be replaced with the official file from Firebase
  Console once `com.nd.chtohochu` is registered there. Until then FCM and
  Firebase Auth clients for Android are misconfigured.
- **Namespace/applicationId divergence.** `namespace` (`ru.nd.chtohochu`) and
  `applicationId` (`com.nd.chtohochu`) differ. This is supported by Android
  Gradle Plugin and has no runtime effect, but developers must not assume they
  are equal.

## Alternatives considered

### Keep `applicationId = "ru.nd.chtohochu"` and register a new Google Play package

Register `ru.nd.chtohochu` in Google Play instead of `com.nd.chtohochu`.

- **Rejected because** the Google Play Console package `com.nd.chtohochu` was
  already created and is the intended store identity. Changing the store
  package would discard existing registration state and require re-creating
  the listing.

### Reuse an existing keystore from the home directory

Several keystores existed outside the project (`keystore.jks`,
`upload-keystore.jks`, a React Native prototype `chtohochu.keystore`).

- **Rejected because** the password to the candidate keystore was lost, and
  reusing a prototype/RN keystore for a new Flutter production app mixes
  unrelated signing identities. A clean, dedicated upload keystore is safer
  and auditable.

### Keep signing `release` with the debug keystore

Leave the Flutter template placeholder as-is.

- **Rejected because** the debug keystore has a public password and a
  `CN=Android Debug` certificate. Google Play does not accept debug-signed
  bundles, and the certificate is not suitable for production distribution.

## References

- AGENTS.md §16 (Security Rules), §23 (AI Agent Rules)
- `apps/client/android/app/build.gradle.kts`
- `apps/client/android/key.properties` (git-ignored)
- `apps/client/android/app/chtohochu-upload.jks` (git-ignored)
