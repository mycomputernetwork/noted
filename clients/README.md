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
- **In development there is no auth service to talk to.** `POST /dev/token`
  with `email=dev1@example.com` returns a real, verifiable token for a fixture
  identity, so the client's token handling is exercised without a second server.
  The endpoint exists only under `AUTH_MODE=stub`.

## Reaching the server in dev

The API is local only. Run the server: `mise exec -- bin/rails s -p 3000`.

The Android app's base URL is a `BuildConfig` field (`BASE_URL`, set per build type in
`app/build.gradle.kts`), defaulting to `http://localhost:3000/`. On the emulator,
bridge the device's `localhost:3000` to the host with:

    adb reverse tcp:3000 tcp:3000   # re-run after every emulator cold boot

`10.0.2.2` (the emulator's host alias) is unreliable here — it can time out even with
the server bound to `0.0.0.0`. `adb reverse` is the dependable path. For a physical
device, point `BASE_URL` at the host's LAN IP instead.

## Build / run (headless, once generated)

    cd clients/android
    ./gradlew assembleDebug        # build the debug APK
    ./gradlew installDebug         # install to a running emulator / device
