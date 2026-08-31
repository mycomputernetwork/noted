# noted clients

Native clients live here, one directory each, each a self-contained project with
its own build system:

- `android/` — Jetpack Compose (Kotlin). **Gradle root.**
- `mac/` — SwiftUI (later). Xcode root.

They share nothing but a contract. Per ADR 0001 §8 there is deliberately
no shared client code and no Kotlin Multiplatform — the shared artefact is the wire
format and the token, not code. Don't add a module both clients import.

## The one rule that keeps the monorepo sane

**The Gradle root is `clients/android`, not the repo root.** Open *that folder* in
Android Studio. Its `settings.gradle.kts` and `gradlew` live there, so the Gradle
build and the Rails app never contend for a root, an `.idea/`, or a `.gitignore`.

## Generating the Android app (Android Studio wizard)

New Project → **Empty Activity** (Compose, Material 3), then:

- Name: `Noted`
- Package name: `app.noted` 
- Save location: `…/work/services/noted/clients/android`
- Language: Kotlin
- Minimum SDK: **API 26 (Android 8.0)** — covers effectively everyone and skips a
  pile of pre-26 workarounds. Raise it later, don't lower it.
- Build configuration language: **Kotlin DSL + Gradle version catalog**

Requires **JDK 17** (the AGP 8.x baseline). Android Studio's bundled JBR satisfies
this; a standalone CLI build needs Temurin 17.

After it generates, confirm `clients/android/.gitignore` (the wizard writes one)
ignores `build/`, `.gradle/`, `local.properties`, `.idea/`, and `*.iml`.
`local.properties` is a machine-specific SDK path and must stay out of git — the
other machine's path differs, so a committed one breaks the other developer's build.

## The contract

`docs/ADR/0001-json-api-alongside-the-web-app.md` is the source of truth, not this file:

- **§3 — representations.** Note/folder JSON, plain text, ISO-8601 UTC datetimes,
  `YYYY-MM-DD` dates, `user_id` never serialised. A field renamed after the client
  parses it is a broken contract, not a refactor — change §3 first, then both sides.
- **§4 — the milestone-16 endpoints** the client builds against:
  `GET/POST /api/v1/notes`, `GET/PATCH/DELETE /api/v1/notes/:id`, and the same for
  `folders`. Filing is `PATCH /notes/:id` with a `folder_id` — it has no endpoint of
  its own, because it's a note with a different folder, not an operation.
- **Bearer tokens now.** `/api/v1` requires `Authorization: Bearer <access token>`
  issued by `auth` (ADR 0003) and returns `401` without one. A native client runs
  Authorization Code + PKCE against `auth` — AppAuth on Android,
  `ASWebAuthenticationSession` on macOS — with no client secret, and keeps the
  refresh token in Keystore/Keychain. Access tokens last 15 minutes; refresh
  before expiry rather than on a `401` alone.
- **A native client signs in for the first time through `POST /api/v1/session`.**
  It presents the **ID token**; noted finds or creates the account behind it and
  returns `{ id, email, name }`. Every other endpoint resolves an existing
  `auth_sub` and never creates one, and an access token carries no email to
  create from. Once per sign-in, not per launch.
- **Sign-out ends auth's session too**, through the same `end_session_endpoint`
  the web app uses — otherwise the browser's cookie signs the next person
  straight back in. Revoke the refresh token as well: `POST /oauth/revoke` with
  the token and `client_id`, no secret.
- `POST /dev/token` is not how Android gets a token any more; it runs the real
  handshake. The endpoint is still there for a client that has none yet.

## Reaching the server in dev

Android needs **two** servers: `mise run server-oidc` here, and `auth` on `:3001`.
AppAuth cannot use the stub issuer — it has no `/oauth/authorize` — so
`AUTH_MODE=stub` is for the web app and the specs, not for a device.

The Android app's base URL is a `BuildConfig` field (`BASE_URL`, set per build type in
`app/build.gradle.kts`), defaulting to `http://localhost:3000/`. On the emulator,
bridge the device's `localhost:3000` to the host with:

    adb reverse tcp:3000 tcp:3000   # re-run after every emulator cold boot
    adb reverse tcp:3001 tcp:3001   # auth, for the browser and the token exchange alike

`10.0.2.2` (the emulator's host alias) is unreliable here — it can time out even with
the server bound to `0.0.0.0`. `adb reverse` is the dependable path. For a physical
device, point `BASE_URL` at the host's LAN IP instead.

## Build / run (headless, once generated)

    cd clients/android
    ./gradlew assembleDebug        # build the debug APK
    ./gradlew installDebug         # install to a running emulator / device

## Release build

Release points at `noted.prabhanshugupta.com` and the `noted-android` client,
refuses cleartext, and is the only build worth trusting a real account to.

GitHub Actions builds signed APKs from tags named `android-v*` and publishes a
GitHub Release with `noted.apk`. The tag sets the APK's `versionName`; the
workflow run number sets `versionCode`. The sign-in page links to that asset and
shows its version/date when GitHub's release API answers.

    git tag android-v1.0.1
    git push origin android-v1.0.1

The workflow reads these repository secrets:

    NOTED_ANDROID_KEYSTORE_BASE64
    NOTED_ANDROID_KEYSTORE_PASSWORD
    NOTED_ANDROID_KEY_ALIAS
    NOTED_ANDROID_KEY_PASSWORD

For a local release-shaped build, keep the matching Gradle properties outside
the repo:

    notedKeystore=/Users/you/.android/noted-release.jks
    notedKeystorePassword=…
    notedKeyAlias=noted
    notedKeyPassword=…

    ./gradlew assembleRelease      # build and sign, touch no device
    ./gradlew installRelease       # and install it to the only device attached

The local artifact is `app/build/outputs/apk/release/app-release.apk`. Sideload it, or
`adb -s <serial> install` it — naming the serial is what keeps an emulator on the
debug build while a phone takes the release one.

One signature per `applicationId` per device: installing a release build over a
debug one fails with `INSTALL_FAILED_UPDATE_INCOMPATIBLE`, and `adb uninstall
app.noted` first is the way through. It takes the tokens and the local cache
with it.

Without those properties the local build still runs and produces
`app-release-unsigned.apk`, which no device will install.
