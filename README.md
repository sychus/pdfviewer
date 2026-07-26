# PDF Viewer

A lightweight, cross-platform PDF reader. One codebase, six targets.

Built on **PDFium** (the rasterizer inside Chrome) via [pdfrx], with a hexagonal architecture
that keeps the rendering engine confined to three files.

[pdfrx]: https://pub.dev/packages/pdfrx

---

## Status

Be aware of what is and is not verified. Nothing below is aspirational.

| Platform | Builds | Runs | Notes |
|---|---|---|---|
| **macOS** | ✅ | ✅ verified | Open, scroll, zoom, resume where you left off |
| **Android** | ✅ | ✅ verified | Verified on a physical device. [Signed APKs are published](https://github.com/sychus/pdfviewer/releases/latest) |
| iOS | — | — | Scaffolded, never built |
| Windows / Linux | — | — | Scaffolded. **Cannot be built on macOS** — Flutter does not cross-compile desktop targets; these need CI runners or native machines |
| Web | — | — | Scaffolded, never built |

### What works today

- Open a PDF through the native file picker
- Scroll and pinch-zoom
- Live page counter
- **Resume where you left off** — and it survives renaming, moving, or copying the file,
  because documents are identified by a fingerprint of their content, not by their path
- **Open with / Share to, on Android** — tap a PDF anywhere on the device and pick PDF Viewer,
  or send one to it from a share sheet. Works whether the app was closed or already running

### What does not work yet

- **Double-clicking a PDF in Finder does not open this app.** File association is Android-only
  so far. Desktop needs different plumbing per OS, and on Windows and Linux a second document
  arrives as a *new process*, making it an IPC problem rather than a file-handling one.
- No text search, no recent-files list, no annotations, no bookmarks. Deliberately out of scope
  for v1.

### Measured

Release builds, on the machine this was developed on:

| Artifact | Size |
|---|---|
| macOS `.app` | 53.8 MB |
| Android arm64-v8a | 23.5 MB |
| Android armeabi-v7a | 18.6 MB |
| Android x86_64 | 25.1 MB |

Opening a 4000-page, 13.3 MB document takes **~2.5 ms** end to end — fingerprint plus parse,
macOS debug build. That number is not a claim, it is a test: see
[`integration_test/open_performance_test.dart`](integration_test/open_performance_test.dart),
which measures across five document profiles and **fails the build** if opening starts scaling
with document size.

---

## Download

Prebuilt binaries are attached to each [release](https://github.com/sychus/pdfviewer/releases).
GitHub Releases has no folders, so platform and architecture live in the filename:

```
pdfviewer-<version>-android-arm64-v8a.apk      ← almost every modern phone
pdfviewer-<version>-android-armeabi-v7a.apk    ← older 32-bit devices
pdfviewer-<version>-android-x86_64.apk         ← emulators
```

To install an APK you must allow installs from your browser or file manager:
**Settings → Apps → Special access → Install unknown apps**.

Other platforms are not published yet — build from source with the instructions below.

---

## Requirements

| Tool | Version | Why |
|---|---|---|
| [fvm] | any recent | The Flutter SDK version is pinned in `.fvmrc`. Do not use a global `flutter`. |
| Flutter | **3.44.8** | Installed by fvm, not by you |

[fvm]: https://fvm.app

> **Always use `fvm flutter …`, never bare `flutter`.**
> The SDK version is pinned in `.fvmrc` so every machine and every CI runner compiles with the
> same toolchain. A bare `flutter` either fails with "command not found" or silently builds with
> a different SDK.

---

## Getting started

```bash
git clone https://github.com/sychus/pdfviewer.git
cd pdfviewer

# Installs the exact SDK named in .fvmrc
fvm install
fvm flutter pub get

fvm flutter doctor
```

Then follow the setup for your target platform below.

---

## macOS

### Prerequisites

```bash
brew install --cask xcode      # or install it from the App Store
brew install cocoapods
```

Xcode 16.4 is what this was developed against. Launch it once to accept the licence and let it
install its components.

### Run it

```bash
fvm flutter run -d macos
```

Hot reload is available: press `r` in the terminal. Press `q` to quit.

To build and launch without tying up a terminal:

```bash
fvm flutter build macos --debug
open build/macos/Build/Products/Debug/pdfviewer.app
```

### The entitlement that makes the file picker work

Flutter's macOS target ships **sandboxed**. Without
`com.apple.security.files.user-selected.read-only`, the sandbox blocks access to whatever the
user picks and **the file picker fails silently** — no panel, no error, nothing at all.

It is already committed in both `macos/Runner/DebugProfile.entitlements` and
`macos/Runner/Release.entitlements`, so a fresh clone works. If you ever meet a dead
"Open a PDF" button, check that it survived into the signed binary:

```bash
codesign -d --entitlements - build/macos/Build/Products/Debug/pdfviewer.app
```

Read-only is deliberate: a viewer never writes back to the PDF, and reading positions live in
the app's own container, which needs no entitlement.

---

## Android

Verified on a physical device. If you only want to run it, grab the APK from
[Releases](https://github.com/sychus/pdfviewer/releases/latest) — everything below is for
building from source.

### Prerequisites

```bash
brew install openjdk@17
brew install --cask android-commandlinetools
```

JDK **17** specifically — it is what the Android Gradle Plugin used here expects. The Homebrew
*formula* (`openjdk@17`) is preferred over the cask: it installs into the Cellar and needs no
`sudo`.

Then install the SDK packages and point Flutter at them:

```bash
export JAVA_HOME="/opt/homebrew/opt/openjdk@17"
export ANDROID_HOME="/opt/homebrew/share/android-commandlinetools"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH"

sdkmanager --licenses          # accepts Google's Android SDK licence
sdkmanager "platform-tools" "platforms;android-36" "build-tools;37.0.0"

fvm flutter config --android-sdk "$ANDROID_HOME"
fvm flutter config --jdk-dir /opt/homebrew/opt/openjdk@17
```

Those two `flutter config` calls persist, so builds work afterwards without the environment
variables. You only need them on your `PATH` for `adb` and `sdkmanager` themselves.

**Do not install the NDK by hand.** Gradle downloads exactly what pdfrx needs on the first
Android build — CMake 3.22.1 and NDK 28.2 — which is roughly 2 GB you would otherwise be guessing
at. That first build takes a few minutes because of it; later ones do not.

### Run it

```bash
fvm flutter devices               # find your device or emulator id
fvm flutter run -d <device-id>
```

Release APKs, split per ABI so users download only their architecture:

```bash
fvm flutter build apk --release --split-per-abi
# build/app/outputs/flutter-apk/app-arm64-v8a-release.apk   <- most devices
```

### Android specifics worth knowing

**SDK levels:** `minSdk 24` (Android 7.0 Nougat), `targetSdk 36` (Android 16). Both inherited
from the Flutter SDK rather than pinned here.

**No storage permissions.** The app declares none. File access goes through the Storage Access
Framework, which grants access to one chosen file at pick time and needs no manifest permission.
For a document reader that is the correct posture — it never asks for your library, only for the
file you handed it.

**The picker returns a cached copy, not the original.** `file_selector_android` resolves the
`content://` URI by copying the file into `{cacheDir}/{randomUuid}/{fileName}`. Two consequences:

- The path is **different every single time** you open the same document — which is exactly why
  reading positions are keyed by a content fingerprint instead of a path. This is the day-one
  design decision paying off.
- Large documents are physically copied before opening. That cost does not exist on desktop, and
  it is the first thing to measure if Android ever feels slower than macOS.

### Signing

Published APKs are signed with a real upload keystore, not debug keys. In Android **the
signature is the app's identity**: once a build is installed, only builds signed with the same
key can update it. Publishing with debug keys and migrating later forces every existing user to
uninstall — losing their reading positions in the process.

The keystore and its password live **outside the repository** and are not distributed.
`android/key.properties` (gitignored) points at them:

```properties
storeFile=/absolute/path/to/upload-keystore.jks
storePassword=…
keyAlias=upload
keyPassword=…
```

**A fresh clone will not have that file, and does not need it.** `build.gradle.kts` detects its
absence and falls back to debug signing, so `flutter build apk --release` works for anyone.
Only builds intended for distribution need the real key.

To set up your own:

```bash
keytool -genkeypair -v -keystore ~/keys/upload.jks \
  -alias upload -keyalg RSA -keysize 2048 -validity 10000
```

`.gitignore` blocks `*.jks`, `*.keystore` and `key.properties`. Worth knowing: Flutter's own
`android/.gitignore` covers `*.keystore` but **not** `*.jks` — the very extension
[its signing guide][signing] tells you to create. That gap is closed in the root `.gitignore`
here.

[signing]: https://docs.flutter.dev/deployment/android#signing-the-app

---

## Tests

```bash
fvm flutter test                    # 22 unit tests, no I/O, no platform
```

Integration tests run against real PDFium and need a device:

```bash
fvm flutter test integration_test/pdfrx_document_repository_test.dart -d macos
fvm flutter test integration_test/open_performance_test.dart -d macos
```

Two things that will bite you:

1. **Run integration test files one at a time.** `fvm flutter test integration_test/` launches
   the app once per file, and the second launch collides with the first still shutting down
   ("Unable to start the app on the device"). A harness limitation, not a test failure.

2. **Integration tests overwrite `build/macos/.../pdfviewer.app`** with a binary whose entrypoint
   is the *test file*, not `lib/main.dart`. Rebuild before launching the app by hand, or you will
   be running a test harness with no UI:

   ```bash
   fvm flutter build macos --debug
   ```

---

## Architecture

```
lib/
  domain/          pure Dart — no Flutter, no pdfrx, no dart:io, no packages at all
    entities/      Document, DocumentId, DocumentSource, ReadingPosition
    repositories/  ports: DocumentRepository, PositionStore
  application/     use cases: OpenDocument, SaveReadingPosition
  infrastructure/  adapters: pdfrx, filesystem, shared_preferences
  presentation/    screens and widgets
```

Two rules, both mechanically checkable:

```bash
rg -c "package:" lib/domain/       # must find nothing — the domain imports no packages
rg -l "package:pdfrx" lib/         # must list exactly three files
```

pdfrx is allowed in exactly three places: the engine bootstrap, the document repository, and
`presentation/widgets/pdf_surface.dart` — the one widget that renders. Screens, use cases and
the domain never see it. Swapping the rendering engine touches those three files and nothing
else.

### Document identity

A document is identified by a fingerprint of its **content**, never by its path:

```
DocumentId = sha256( first 64KB ‖ last 64KB ‖ total size )
```

Constant cost regardless of file size — a 500 MB PDF reads 128 KB, same as a 2 MB one. A full
hash would be a perfect identifier but would read the whole file before showing page one.

Paths were rejected because they are unstable on every platform this ships to: Android hands out
`content://` URIs that resolve to a fresh cached copy each time, iOS paths embed a sandbox
container UUID that changes on app update, and desktop users move and rename files. The
tradeoffs — including the case where two documents differing only in their middle bytes collide
— are pinned as tests in
[`test/infrastructure/identity/`](test/infrastructure/identity/fingerprint_document_identity_test.dart).

---

## Licence

GPL-3.0. See [LICENSE](LICENSE).

PDFium is BSD-3-Clause and pdfrx is MIT; both are compatible with GPL-3.0.
