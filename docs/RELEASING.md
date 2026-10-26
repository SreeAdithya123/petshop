# Releasing PETSTA (Android + iOS)

How to cut a store build of the Flutter app in `mobile/`. Read
[`production-checklist.md`](production-checklist.md) first for the things only
the owner can do (store accounts, Supabase settings, legal) and
[`store-listing.md`](store-listing.md) for the store text, screenshots and
privacy answers.

| | Android | iOS |
|---|---|---|
| Identifier | `com.pawsnearby.pawsnearby` | `com.petsta.pawsnearby` |
| Display name | PETSTA | PETSTA |
| Build on | Windows (or any OS) | A Mac with Xcode only |
| Artifact | `.aab` (Play) / `.apk` (side-load) | `.ipa` (App Store Connect) |

Both identifiers are permanent once the first build is uploaded. Do not change
them.

## 1. Before every release

1. `git status` is clean and you are on the release commit.
2. From `mobile/`:
   ```
   flutter pub get
   flutter analyze
   flutter test
   ```
3. Bump the version in `mobile/pubspec.yaml` (see below).
4. Smoke-test a **release** build on a real phone (`flutter run --release`):
   sign up / sign in, password-reset email link, browse pets, reserve, cart and
   checkout, a service booking, a vet consult link, the seller dashboard and
   account deletion. Debug builds hide R8 and obfuscation problems.
5. Tag it: `git tag v1.0.0+1 && git push origin v1.0.0+1`.

## 2. Versioning

`version: 1.0.0+1` in `mobile/pubspec.yaml` is `<versionName>+<build number>`.

- The part before `+` is the user-visible version (Play `versionName`, iOS
  `CFBundleShortVersionString`). Use semver: bug fix `1.0.1`, feature `1.1.0`.
- The number after `+` is Play `versionCode` and iOS `CFBundleVersion`. It must
  be **higher on every upload** to the same store, even for a re-upload of the
  same `versionName`. Keep one counter for both stores (`1.0.0+1`, `1.0.0+2`,
  `1.0.1+3`, ...). Play rejects values above 2,100,000,000.

You can also override on the command line without editing the file:
`--build-name 1.0.1 --build-number 3`. Keep `pubspec.yaml` and the tag in sync
so the next person knows what shipped.

## 3. Android

### 3.1 One-time: upload keystore

The release signing key already exists on the machine that set the project up:

- `mobile/android/app/upload-keystore.jks` (PKCS12, alias `upload`)
- `mobile/android/key.properties` (store/key password, alias, path)

Both are git-ignored (`mobile/.gitignore`, `mobile/android/.gitignore`). Only
the format is committed: `mobile/android/key.properties.example`.

> **Back both files up now**, to a password manager and an offline copy
> (encrypted USB or cloud vault). If the upload key is lost you can still ship
> through Play, but only after Google verifies you and resets the upload key
> (Play Console, App integrity, App signing, Request upload key reset), which
> takes days. Never commit them, paste them into chat or CI logs, or email them.

To set up on another machine, copy both files to the same paths. To create a
fresh keystore (new project only; this makes a *different* key):

```
keytool -genkeypair -storetype PKCS12 -keystore app/upload-keystore.jks ^
  -alias upload -keyalg RSA -keysize 2048 -validity 10000
```

(run inside `mobile/android`; `keytool` ships with Android Studio, for example
`D:\Android\Android Studio\jbr\bin\keytool.exe`). Then copy
`key.properties.example` to `key.properties` and fill it in.

Without `key.properties`, `flutter build` still works but signs the release
build with the **debug** key. That build can be installed for testing but Play
will reject it. CI and other contributors rely on this fallback.

### 3.2 Play App Signing

Enrol in Play App Signing when you create the app in Play Console (it is the
default for new apps). Google then holds the real app-signing key and the
keystore above is only the **upload key** that proves uploads come from you.
This is why a lost upload key is recoverable and a lost app-signing key would
not be.

### 3.3 Build

From `mobile/` (Windows PowerShell shown; the Flutter SDK must be on `PATH`):

```
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols
```

Output: `build/app/outputs/bundle/release/app-release.aab`. R8 shrinking and
obfuscation are on for release (`android/app/build.gradle.kts`,
`android/app/proguard-rules.pro`); the mapping file is embedded in the bundle
so Play can de-obfuscate native crashes.

An installable APK for testers or a direct download:

```
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols
```

Output: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (and the
armeabi-v7a / x86_64 variants).

**Keep `build/symbols/`.** It is what turns obfuscated Dart stack traces back
into readable ones (`flutter symbolize -i crash.txt -d build/symbols`) and is
specific to the exact build. Zip it as `symbols-1.0.0+1.zip` and store it with
the keystore backup. It is git-ignored.

Verify the signing key before uploading (`apksigner` is in
`%ANDROID_HOME%\build-tools\<version>\`):

```
apksigner verify --print-certs build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
```

The certificate owner must not be "Android Debug". For the bundle:
`jarsigner -verify -verbose -certs build\app\outputs\bundle\release\app-release.aab`.

### 3.4 Upload to Google Play

1. Play Console, Create app. Name `PETSTA`, default language, App, Free.
2. Complete **App content** (Policy section): privacy policy URL, ads (none),
   app access (login is required, so give reviewers demo customer and shop-owner
   accounts), content rating questionnaire, target audience (not for children),
   Data safety form, account deletion URL, government/financial/health
   declarations as applicable. Answers are in `store-listing.md`.
3. Testing, Internal testing, Create release, upload the `.aab`, add release
   notes, Save, Review, Start rollout. Add yourself and testers by email.
4. New personal developer accounts must run a **closed test** with a minimum
   number of testers (currently 12, for 14 continuous days) before Production
   access is offered. Organisation accounts are exempt. Check the current rule
   in Play Console help.
5. Production, Create release (promote the tested bundle), staged rollout
   (for example 10 percent, then 50, then 100).
6. Play may show a non-blocking warning that the bundle has no native debug
   symbols. It does not affect the release.

Each later release: bump the build number, build the `.aab`, upload to the same
track, roll out.

## 4. iOS (on a Mac)

iOS cannot be built on Windows. Everything below runs on the MacBook with
Xcode. Commands are for Terminal in the project folder
(`~/Documents/petshop/mobile` on the current Mac).

### 4.1 One-time Apple setup

- An Apple Developer Program membership (paid, annual).
- developer.apple.com, Certificates, Identifiers: register the App ID
  `com.petsta.pawsnearby`.
- App Store Connect, My Apps, New App: platform iOS, name `PETSTA`, primary
  language, bundle ID `com.petsta.pawsnearby`, SKU any unique string.
- Xcode, Settings, Accounts: sign in with the Apple ID of the developer team.

### 4.2 Get the code and prepare

```
git status
git pull
flutter pub get
cd ios
pod install
cd ..
```

If `git status` shows edits the Mac made to the project (see 4.5), commit them
or `git stash` before `git pull`.

### 4.3 Build the archive

```
flutter build ipa --release --obfuscate --split-debug-info=build/symbols
```

Output: `build/ios/archive/Runner.xcarchive` and, when signing is set up,
`build/ios/ipa/*.ipa`. If the command stops with a signing error, do the
Xcode steps once:

1. `open ios/Runner.xcworkspace` (always the `.xcworkspace`, never the
   `.xcodeproj`).
2. In the left list click **Runner** (blue icon), then the **Runner** target,
   tab **Signing & Capabilities**.
3. Tick **Automatically manage signing** and pick your **Team**. The Bundle
   Identifier must read `com.petsta.pawsnearby`.
4. Add the privacy manifest once (see 4.5), then repeat the build command.

### 4.4 Upload and TestFlight

Option A, from Xcode (no extra tools):

1. In the top bar choose **Any iOS Device (arm64)** as the run destination.
2. Menu **Product, Archive**. The Organizer window opens when it finishes.
3. Select the archive, **Distribute App, App Store Connect, Upload**, click
   through the defaults, then **Upload**. If Xcode offers to manage the version
   and build number for you, switch that off so the numbers from `pubspec.yaml`
   are kept.

Option B, command line (needs an App Store Connect API key; first run
`flutter build ipa` so the `.ipa` exists):

```
xcrun altool --upload-app -f build/ios/ipa/*.ipa -t ios \
  --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>
```

Then in App Store Connect, TestFlight: wait for "Processing" to finish (about
10 to 30 minutes), then add Internal Testers (up to 100 members of your team).
Export compliance is pre-answered by `ITSAppUsesNonExemptEncryption = false` in
`Info.plist`. External testers need a short Beta App Review. For the store
release: App Store tab, add the build to a version, fill the listing, privacy
labels and review notes (`store-listing.md`), **Submit for Review**.

Apple requires builds to come from the Xcode / SDK version it currently
mandates; use the latest Xcode from the App Store.

### 4.5 First-run notes (SwiftPM, CocoaPods, Podfile)

- Run `flutter build ios` / `flutter run` from the command line **once** before
  using Xcode's own build button. Newer Flutter wires some plugins in through
  Swift Package Manager, and only the `flutter` tool performs that step.
  Symptom of skipping it: `Module 'app_links' not found` in Xcode.
- On the first run Flutter may rewrite `ios/Podfile`, `AppFrameworkInfo.plist`,
  `project.pbxproj` and migrate the app to the UIScene lifecycle. Those edits
  are legitimate; commit them from the Mac once the app builds, so the repo
  and the Mac agree.
- The repo says `platform :ios, '13.0'` (Podfile and
  `IPHONEOS_DEPLOYMENT_TARGET`). If `pod install` or the build complains that a
  plugin needs a newer iOS, raise both to the version in the error message and
  commit.
- **Add `ios/Runner/PrivacyInfo.xcprivacy` to the Runner target once.** The file
  is in the repo but not yet listed in `project.pbxproj`. In Xcode: right-click
  the **Runner** folder in the left list, **Add Files to "Runner"...**, choose
  `PrivacyInfo.xcprivacy`, make sure **Copy items if needed** is off and the
  **Runner** target is ticked, **Add**. Without this Apple e-mails a "missing
  privacy manifest" warning after upload.
- Auth deep link: `Info.plist` registers the `io.supabase.petsta` URL scheme.
  Nothing to do on the Mac, but the redirect URL must be allowed in Supabase
  (see `production-checklist.md`).

## 5. Troubleshooting

- **Release build crashes on launch but debug works.** Almost always R8 or
  obfuscation. Run `flutter run --release`, read `adb logcat`, and add a
  `-keep` rule to `android/app/proguard-rules.pro` for the class named in the
  crash.
- **R8 "Missing class ..." build error.** Add `-dontwarn <package>.**` for the
  package in the message to `proguard-rules.pro`.
- **"Keystore was tampered with, or password was incorrect".** `key.properties`
  does not match the keystore. Check `storePassword` and `storeFile` (the path
  is relative to `android/app/`).
- **Play: "You uploaded a debug-signed bundle".** `key.properties` was missing
  on the build machine.
- **Play: "Version code N has already been used".** Raise the number after `+`.
- **Password-reset link opens a browser, not the app.** The redirect URL is not
  in the Supabase allow-list or the Site URL is wrong; see the checklist.
