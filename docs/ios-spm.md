# iOS: Swift Package Manager

This page covers GoogleSignIn resolution through Swift Package Manager (SPM), why React Native's CocoaPods-free SPM mode is not supported yet, and the test plan for a Mac.

## Dependency ranges

Checked 2026-10-25.

|                                    | AppCheckCore    | GoogleUtilities |
| ---------------------------------- | --------------- | --------------- |
| GoogleSignIn 10.0.0 (pod and SPM)  | 11.x only       | 8.x             |
| GoogleSignIn 10.1.0 (pod and SPM)  | >= 11.0, < 13.0 | 8.x             |
| firebase-ios-sdk 12.19             | 11.3 ..< 12     | 8.x             |
| firebase-ios-sdk 13.1.1 (SPM only) | 12.0.0 ..< 13   | 8.1.4 ..< 9     |

Firebase iOS 13 is not on CocoaPods trunk; `FirebaseCore` stops at 12.19.3. React Native Firebase 27 resolves Firebase only through `spm_dependency`. If this library kept the `GoogleSignIn` CocoaPod, the app would get `AppCheckCore` and `GoogleUtilities` twice: once from SPM through Firebase, and once as pods through GoogleSignIn.

## Setup 2: CocoaPods with GoogleSignIn from SPM

`google_auth_spm.rb` is loaded by both podspecs.

- **Opt-in, not detected.** A podspec is evaluated before the Podfile's linkage is applied, and it cannot read that linkage reliably. `ENV['USE_FRAMEWORKS']` misses a hard-coded `use_frameworks!`, and re-reading the Podfile would evaluate it again. Switching a static app to SPM would break its link, so SPM is used only when the Podfile sets `$GoogleAuthUseSPM = true`. The Expo plugin option `iosUseSwiftPackageManager: true` writes that line. The value is checked, not just `defined?`, so a generated `$GoogleAuthUseSPM = false` keeps CocoaPods.
- **Fallback.** When `spm_dependency` is undefined (React Native < 0.75), the flag is ignored with a `pod install` warning and the CocoaPod is used.
- **`GoogleAuth.podspec`** calls `spm_dependency(s, url: 'https://github.com/google/GoogleSignIn-iOS.git', requirement: {kind: 'upToNextMajorVersion', minimumVersion: '10.1.0'}, products: ['GoogleSignIn'])` instead of `s.dependency 'GoogleSignIn', '~> 10.0'`. React Native's `SPMManager` adds one `XCRemoteSwiftPackageReference` per URL to `Pods.xcodeproj`, beside React Native Firebase's `firebase-ios-sdk` reference. Xcode resolves both in one package graph.
- **`ExpoAdapterGoogleAuth.podspec`** declares no GoogleSignIn dependency in SPM mode. It also drops `GoogleUtilities` and `RecaptchaInterop`, and sets the Swift condition `GOOGLE_AUTH_SPM`.
  - **Why not link the product here too:** the adapter is a static framework and `GoogleAuth` is a dynamic framework (or a static library after Expo's precompiled-module downgrade). Swift package products link statically into each target that uses them, so a second consumer risks a second copy of GoogleSignIn. That copy would have its own `GIDSignIn.sharedInstance`, so the sign-in URL would reach an instance that never started the flow.
  - **What it does instead:** `GoogleAuthAppDelegate.swift` looks up `GIDSignIn` with `NSClassFromString` and calls `+sharedInstance` and `-handleURL:` through their implementations. Both selectors are confirmed in `GIDSignIn.h` of GoogleSignIn-iOS 10.1.0.
  - **Imports:** with no `import GoogleSignIn` in the adapter, the old reason for listing `GoogleUtilities` and `RecaptchaInterop` (AppCheckCore's Swift imports need modular headers) no longer applies. SPM C targets ship their own module maps, so AppCheckCore's imports resolve inside the package graph either way.
- The CocoaPods path is unchanged. Evaluated with CocoaPods 1.17, both podspecs produce the same spec as `main` when the flag is unset or `false`. The only difference is the corrected `s.source` URL.

## Setup 3: `npx react-native spm` is blocked

This library cannot be consumed without NitroModules, and NitroModules 0.37 has no SPM support.

- `react-native-nitro-modules` 0.37.1 (npm `latest`) and `0.37.2-nightly.62` ship no `Package.swift` and no `swiftpmConfig`. React Native's scaffolder (`scripts/spm/scaffold-package-swift.js`) refuses NitroModules as `skipped-mixed-language`, because the pod mixes 11 Swift files with C++ and ObjC++ in one target.
- SPM support exists only on Nitro's unreleased `v1` branch, published as `1.0.0-alpha.nightly.*` (npm tag `alpha-nightly`). It is a breaking rewrite:
  - requires React Native 0.88 and the New Architecture
  - uses decorated-class specs
  - moves `ios/` to `apple/`
  - requires Swift 6 language mode
  - generates its SPM targets with nitrogen's `addNitrogenTargets(to:)`
- Upstream:
  - [margelo/nitro#1045](https://github.com/margelo/nitro/issues/1045) "iOS SPM Support" (open)
  - [#1780](https://github.com/margelo/nitro/pull/1780) "build: use SwiftPM for runtime and generated modules" (merged into `v1`)
  - [#1781](https://github.com/margelo/nitro/pull/1781) "migrate React Native apps and iOS CI to SwiftPM"
  - [#1784](https://github.com/margelo/nitro/pull/1784) "require React Native 0.88"
  - [#1838](https://github.com/margelo/nitro/pull/1838) "SwiftPM header search paths for generated targets"
  - [#1960](https://github.com/margelo/nitro/pull/1960) "move Apple sources and generated code to apple/"
- Even with a NitroModules package, this module cannot be split into plain SPM targets:
  - SwiftPM has no mixed Swift and C-family targets. SE-0403 was returned for revision, and the follow-up pitch is not in a toolchain.
  - Nitro's generated code needs Swift ↔ C++ in both directions. The Swift sources `import NitroModules` and use the C++ bridge namespace (`margelo.nitro.googleauth.bridge.swift`). The C++ and ObjC++ sources include `GoogleAuth-Swift.h` through `GoogleAuth-Swift-Cxx-Umbrella.hpp`, namely `HybridGoogleAuthSpecSwift.hpp`, `GoogleAuth-Swift-Cxx-Bridge.cpp` and `GoogleAuthAutolinking.mm`.
  - It can be split as C++ headers, then Swift, then a C++ bridge target. But the bridge target needs the generated Swift header of a target it depends on. Nitro v1 gets it through `-I${GENERATED_MODULEMAP_DIR}`, which only Xcode and the Swift Build backend provide, not plain SwiftPM.
- The Expo adapter target has a separate problem, because it shares this package's root. Expo's SwiftPM plugin (`expo/scripts/spm`) resolves the module root to the npm package root.
  - **Without a root `Package.swift`,** it classifies `<root>/ios` (the Nitro Swift sources) as a pure-Swift module and generates `ExpoAdapterGoogleAuth` over the wrong files.
  - **With a root `Package.swift`,** it mirrors every regular target in that manifest and rejects local-path package dependencies (`local-path`). A path dependency on NitroModules is exactly that.
  - **The fix:** a root manifest written for Expo's "direct" mode, which depends on the `ExpoModulesCoreHeaders` product and must be valid from both the React Native autolinker's `libs/<SwiftName>` symlink and Expo's `direct/<npm name>` symlink. Moving the adapter into its own npm package is the other way out.

### What unblocks setup 3

1. Nitro v1 is released, with `Package.swift` and `swiftpmConfig`, and this library migrates to it. That migration needs a nitrogen bump, decorated-class specs, the `apple/` layout and regenerated bindings. It is out of scope here: it changes the spec sources.
2. Regenerate with nitrogen v1, which emits `addNitrogenTargets(to:)`, and add `"swiftpmConfig": { "name": "GoogleAuth", "dependencies": ["react-native-nitro-modules"] }`.
3. Declare GoogleSignIn-iOS (`from: "10.1.0"`) in that manifest, and give the Expo adapter a target that satisfies Expo's plugin as described above.

## Verified on Linux

These checks ran in a Linux container with no Xcode:

- **SPM resolve (Swift 6.2.4).** A throwaway package depending on firebase-ios-sdk `exact: 13.1.1` (`FirebaseMessaging`) and GoogleSignIn-iOS `.upToNextMajor(from: "10.1.0")` (`GoogleSignIn`) resolves to:

  - `app-check` 12.0.0
  - `googleutilities` 8.1.5
  - `googlesignin-ios` 10.1.0
  - `gtmappauth` 6.0.0
  - `appauth-ios` 3.0.0
  - `gtm-session-fetcher` 5.3.1

  Firebase 13 requires Swift 6.2.3 or later, so 6.2 fails to read its manifest.

- **Negative control.** Pinning GoogleSignIn-iOS to `exact: 10.0.0` fails: "'googlesignin-ios' 10.0.0 depends on 'app-check' 11.0.0..<12.0.0 and 'firebase-ios-sdk' 13.1.1 depends on 'app-check' 12.0.0..<13.0.0".
- **Podspecs (CocoaPods 1.17).** Both podspecs were evaluated with the flag unset, `false`, `true`, and `true` without `spm_dependency`:
  - Unset, `false`, and `true` without `spm_dependency` all match `main`, apart from the `s.source` URL fix.
  - `true` removes the `GoogleSignIn`, `GoogleUtilities` and `RecaptchaInterop` pods, adds `GOOGLE_AUTH_SPM`, and makes exactly one `spm_dependency` call, for `GoogleAuth`.
- **React Native's `SPMManager.apply_on_post_install`** (from `react-native@0.88.0`) ran on a generated `Pods.xcodeproj` with `GoogleAuth`, `ExpoAdapterGoogleAuth` and a stand-in `RNFBMessaging` target.
  - The project gets two remote package references, GoogleSignIn-iOS (`upToNextMajorVersion 10.1.0`) and firebase-ios-sdk.
  - Product dependencies: `GoogleSignIn` on `GoogleAuth` only, and `FirebaseMessaging` on `RNFBMessaging`.
- **Expo plugin.** It writes `$GoogleAuthUseSPM = true` after `platform :ios` in the Podfile from `expo prebuild` (SDK 58). The write is idempotent, and turning the option off removes the line.

Not verified: any Xcode build, link or run. The test plan below covers them.

## Mac test plan

Use Xcode 26.2 or later (Firebase 13 needs Swift 6.2.3), React Native 0.88, and an iOS 16.4 simulator. For each app, keep the `pod install` log and the Xcode build log.

### A. Baseline: RNFB 26, static (setup 1, must be unchanged)

1. Create an RN 0.88 app with `@react-native-firebase/app` and `@react-native-firebase/messaging` 26.x, this library, and `use_frameworks! :linkage => :static`. Do not set `$GoogleAuthUseSPM`.
2. Run `pod install`.
   - `Podfile.lock` lists `GoogleSignIn (10.x)`, `AppCheckCore (11.x)`, `GoogleUtilities (8.x)` and `FirebaseCore (12.x)`.
   - There is no `[SPM]` log line from this library.
3. Build and launch on the iOS 16.4 simulator. Sign in with Google: `signIn()` resolves with an `idToken`.
4. Repeat with the Expo example (`packages/example`, Expo SDK 58, default static), using `expo prebuild` and `expo run:ios`. The URL callback reaches the Expo adapter and sign-in completes.

### B. RNFB 27, dynamic frameworks, bare RN (setup 2)

1. Create an RN 0.88 app with `@react-native-firebase/app` and `@react-native-firebase/messaging` 27.x, this library, `use_frameworks! :linkage => :dynamic`, and `$GoogleAuthUseSPM = true` in the Podfile.
2. Run `pod install`.
   - The log shows `[react-native-nitro-google-auth] GoogleAuth: using SPM for GoogleSignIn` and `[SPM] Adding product dependency GoogleSignIn to GoogleAuth`.
   - `Podfile.lock` has no `GoogleSignIn`, `AppCheckCore`, `GoogleUtilities` or `RecaptchaInterop` pods.
3. Open the workspace. Under Package Dependencies there is exactly one `app-check` (12.x) and one `GoogleUtilities` (8.x). Record the resolved versions from `Pods.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.
4. Add the README's `handleGoogleSignInURL` to `SceneDelegate`, then build and launch on the iOS 16.4 simulator. Capture the console from launch:
   - There are no `Class GUL… is implemented in both`, `Class GAC… is implemented in both` or `Class GID… is implemented in both` warnings.
   - Run `xcrun simctl spawn booted log show --last 5m --predicate 'eventMessage CONTAINS "is implemented in both"'` and confirm it prints nothing.
5. Check which binaries define the GoogleUtilities and GoogleSignIn classes. In the built `.app`, run:

   ```sh
   for f in example.app/example example.app/Frameworks/*.framework; do
     [ -d "$f" ] && f="$f/$(basename "$f" .framework)"
     nm -m "$f" 2>/dev/null | grep -v undefined | grep -q '_OBJC_CLASS_$_GULAppEnvironmentUtil' && echo "$f"
   done
   ```

   Repeat with `_OBJC_CLASS_$_GIDSignIn` and `_OBJC_CLASS_$_GACAppCheck`. Each class must be defined in exactly one binary.

6. Sign in with Google: `signIn()` resolves with an `idToken`. Messaging still gets an FCM token.
7. Archive (Release, Any iOS Device) and run `xcrun altool --validate-app` or upload to TestFlight. Confirm there is no missing-framework dyld error and no "Invalid bundle structure".

### C. RNFB 27, dynamic frameworks, Expo SDK 58 (setup 2)

1. In the example app, add `@react-native-firebase/app` and `@react-native-firebase/messaging` 27.x. Add `expo-build-properties` with `ios.useFrameworks: "dynamic"`, and add `iosUseSwiftPackageManager: true` to this library's plugin options.
2. Run `npx expo prebuild --clean -p ios`. The Podfile contains the `$GoogleAuthUseSPM = true` block.
3. Repeat B2–B7. Expo's adapter forwards the URL, so `AppDelegate` needs no change. In the console, sign-in must not log `[react-native-nitro-google-auth] Failed to handle sign-in URL`.
4. Run it twice: with the default `EXPO_USE_PRECOMPILED_MODULES=1` from the SDK 58 Podfile, and with `EXPO_USE_PRECOMPILED_MODULES=0`. In the first, Expo downgrades `GoogleAuth` to a static library, because it depends on React-Core. Check B4 and B5 in both runs. If the downgraded run shows duplicate GUL classes, record which binaries define them.

### D. Fallbacks

1. Setup B with `$GoogleAuthUseSPM` removed. `pod install` uses the `GoogleSignIn` CocoaPod, which brings `AppCheckCore` 11.x and `GoogleUtilities` as pods next to Firebase's SPM copies. Record whether the app logs duplicate `GUL` classes or fails to link. This is the problem setup 2 fixes, and it confirms the flag is needed.
2. Static linkage with `$GoogleAuthUseSPM = true` and no RNFB. Record whether the build links. React Native warns "using swift package(s) GoogleSignIn with static linking". The README tells users to combine the flag with dynamic frameworks.
