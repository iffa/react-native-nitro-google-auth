# react-native-nitro-google-auth

Sign in with Google for React Native, built with Nitro.

[![Version](https://img.shields.io/npm/v/react-native-nitro-google-auth.svg)](https://www.npmjs.com/package/react-native-nitro-google-auth)
[![Downloads](https://img.shields.io/npm/dm/react-native-nitro-google-auth.svg)](https://www.npmjs.com/package/react-native-nitro-google-auth)
[![License](https://img.shields.io/npm/l/react-native-nitro-google-auth.svg)](https://github.com/iffa/react-native-nitro-google-auth/LICENSE)

## Quick start (Expo)

1. Install:

   ```bash
   npx expo install react-native-nitro-google-auth react-native-nitro-modules
   ```

2. Create **Web** and **iOS** OAuth clients (plus **Android**, see [OAuth clients](#oauth-clients)) in one Google Cloud project.

3. Add the config plugin. Pick the track that matches your Firebase setup:

   **CocoaPods (default)**: no Firebase, or `@react-native-firebase/*` 26.x.

   ```ts
   plugins: [
     ["react-native-nitro-google-auth", { iosUrlScheme: "com.googleusercontent.apps.123456789-abc" }],
   ],
   ```

   **Swift Package Manager**: `@react-native-firebase/*` 27.x (Firebase 13). Resolves GoogleSignIn through SPM so it shares Firebase's `AppCheckCore` and `GoogleUtilities`.

   ```ts
   plugins: [
     ["react-native-nitro-google-auth", { iosUrlScheme: "com.googleusercontent.apps.123456789-abc", iosUseSwiftPackageManager: true }],
     ["expo-build-properties", { ios: { useFrameworks: "dynamic" } }],
   ],
   ```

   `iosUrlScheme` is the **reversed** iOS client ID.

4. Run `npx expo prebuild`, then build the app.

5. Sign in:

   ```ts
   import { GoogleAuth } from "react-native-nitro-google-auth";

   GoogleAuth.configure({
     iosClientId: "YOUR_IOS_CLIENT_ID.apps.googleusercontent.com",
     webClientId: "YOUR_WEB_CLIENT_ID.apps.googleusercontent.com",
   });

   const result = await GoogleAuth.signIn();
   if (result.data) {
     // Send result.data.idToken to your backend.
   } else if (result.error?.code !== "CANCELLED") {
     // Handle result.error.code.
   }

   await GoogleAuth.signOut();
   ```

The library is headless: build your own button following the [Sign in with Google branding guidelines](https://developers.google.com/identity/branding-guidelines).

## Requirements

| Dependency                      | Minimum |
| ------------------------------- | ------- |
| React Native                    | 0.75    |
| `react-native-nitro-modules`    | 0.37    |
| iOS deployment target           | 15.1    |
| Android `minSdk` / `compileSdk` | 24 / 35 |

React Native's CocoaPods-free `npx react-native spm` mode is not supported yet: `react-native-nitro-modules` 0.37 ships no `Package.swift` ([margelo/nitro#1045](https://github.com/margelo/nitro/issues/1045)).

## OAuth clients

Create them in one project under [Google Cloud Console → Clients](https://console.cloud.google.com/auth/clients).

| Client      | Notes                                                                  |
| ----------- | ---------------------------------------------------------------------- |
| **Web**     | Its client ID is `webClientId`.                                        |
| **iOS**     | Bundle ID must match the app. Its client ID is `iosClientId`.          |
| **Android** | One per package name + signing certificate SHA-1 of the build you run. |

## Bare React Native (iOS)

Install with `npm install react-native-nitro-google-auth react-native-nitro-modules`, then:

1. Add the reversed iOS client ID to `CFBundleURLTypes`.
2. Forward opened URLs to Google Sign-In in `SceneDelegate.swift`:

   ```swift
   import GoogleSignIn

   func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
     for context in URLContexts where GIDSignIn.sharedInstance.handle(context.url) {
       return
     }
     RCTLinkingManager.scene(scene, openURLContexts: URLContexts)
   }
   ```

3. Without `use_frameworks!`, enable modular headers in the Podfile app target:

   ```ruby
   pod 'GoogleUtilities', :modular_headers => true
   pod 'RecaptchaInterop', :modular_headers => true
   ```

For the Swift Package Manager track, set `$GoogleAuthUseSPM = true` and `use_frameworks! :linkage => :dynamic` in the Podfile. The app target then can't `import GoogleSignIn`, so forward the URL through the Objective-C runtime:

```swift
func handleGoogleSignInURL(_ url: URL) -> Bool {
  guard let signIn = NSClassFromString("GIDSignIn"),
        let shared = class_getClassMethod(signIn, NSSelectorFromString("sharedInstance")),
        let handle = class_getInstanceMethod(signIn, NSSelectorFromString("handleURL:"))
  else { return false }
  typealias Shared = @convention(c) (AnyClass, Selector) -> Unmanaged<AnyObject>
  typealias Handle = @convention(c) (AnyObject, Selector, NSURL) -> ObjCBool
  let instance = unsafeBitCast(method_getImplementation(shared), to: Shared.self)(
    signIn, NSSelectorFromString("sharedInstance")
  ).takeUnretainedValue()
  return unsafeBitCast(method_getImplementation(handle), to: Handle.self)(
    instance, NSSelectorFromString("handleURL:"), url as NSURL
  ).boolValue
}
```

### Podfile notes for React Native Firebase 26

With static frameworks, React Native Firebase 26 stops `pod install` until its SPM mode is off:

```ruby
$RNFirebaseDisableSPM = true
```

Xcode 27 rejects pod targets below iOS 15, which the Firebase CocoaPods resource bundles still use. Raise them in `post_install`:

```ruby
post_install do |installer|
  # react_native_post_install(...)
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      if config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'].to_f < min_ios_version_supported.to_f
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = min_ios_version_supported
      end
    end
  end
end
```

## API

- `GoogleAuth.configure(config)`
  - `iosClientId?: string`
  - `webClientId?: string`
- `GoogleAuth.signIn(): Promise<GoogleSignInResult>`
  - `data?: GoogleUserData`
    - `idToken: string`
    - `providerUserId: string`
    - `email?: string`
    - `name?: string`
    - `photoUrl?: string`
  - `error?: GoogleSignInError`
    - `code: string`
    - `message: string`
    - `android?: GoogleSignInAndroidDiagnostics`
      - `playServicesStatus: number`, the native `ConnectionResult` status code
      - `playServicesVersion?: string`, the installed version, if available
      - `nativeExceptionType: string`
      - `nativeMessage?: string`
      - `nativeStackTrace: string`
- `GoogleAuth.signOut(): Promise<void>`

### Sign-in errors

Cancellation, missing credentials, a missing window, and Android provider configuration failures resolve with `result.error` and no `result.data`. Other failures reject the promise, so callers must also handle rejected promises.

| Code                              | Meaning and suggested action                                                                                                                                                         |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `CANCELLED`                       | The user closed sign-in. No error message is needed.                                                                                                                                 |
| `NO_CREDENTIALS`                  | No Google credentials are available. Check that the device has a Google account. Android only.                                                                                       |
| `PLAY_SERVICES_MISSING`           | Google Play services is not installed. Offer another sign-in method.                                                                                                                 |
| `PLAY_SERVICES_DISABLED`          | Ask the user to enable Google Play services in device settings.                                                                                                                      |
| `PLAY_SERVICES_UPDATE_REQUIRED`   | Ask the user to update Google Play services.                                                                                                                                         |
| `PLAY_SERVICES_UPDATING`          | Ask the user to retry after the update finishes.                                                                                                                                     |
| `PLAY_SERVICES_INVALID`           | Google Play services failed its validity check. Offer another sign-in method.                                                                                                        |
| `PLAY_SERVICES_UNAVAILABLE`       | Another Play services availability failure occurred. Inspect `error.android.playServicesStatus`.                                                                                     |
| `CREDENTIAL_PROVIDER_UNAVAILABLE` | Play services passed its availability check, but Credential Manager could not use a provider. Inspect the native diagnostics and the app's merged Android manifest and dependencies. |
| `NO_ACTIVE_WINDOW`                | No window could present sign-in. The app had no active scene for 5 seconds after the call, for example under Control Center. iOS only. Ask the user to try again.                    |

`PLAY_SERVICES_*` and `CREDENTIAL_PROVIDER_UNAVAILABLE` are Android-only; the native exception is kept in `error.android`. The library never shows UI on its own.

## Troubleshooting

| Symptom                                                                       | Checks                                                                                                          |
| ----------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| Android: `NoCredentialException`, `Developer console is not set up correctly` | `webClientId` is a **Web** client; the Android client matches package name + SHA-1; all clients in one project. |
| iOS sign-in fails                                                             | Bundle ID matches the iOS client; `iosUrlScheme` is the **reversed** client ID; bare apps forward opened URLs.  |

## References

- [Android Sign in with Google (Credential Manager)](https://developer.android.com/identity/sign-in/credential-manager-siwg-implementation#create-button)
- [Credential Manager troubleshooting](https://developer.android.com/identity/sign-in/credential-manager-troubleshooting-guide)

## Credits

Bootstrapped with [create-nitro-module](https://github.com/patrickkabwe/create-nitro-module).

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

### Verification

```bash
bun install --frozen-lockfile
bun run build
bun run --filter example prebuild --platform android --no-install
```

From `packages/example/android`, run the native tests and build:

```bash
./gradlew :react-native-nitro-google-auth:testDebugUnitTest :app:assembleDebug
```

Set `ANDROID_HOME` to your Android SDK directory before running Gradle.

For the iOS example, generate the native project with `bun run --filter example prebuild --platform ios --no-install`. From `packages/example/ios`, run `LANG=en_US.UTF-8 pod install`, then build `example.xcworkspace` in Xcode.

After changing the Nitro spec, run `bun run --filter react-native-nitro-google-auth codegen` and commit the generated bindings.

### Publishing

Update the library version in `packages/react-native-nitro-google-auth/package.json`, refresh `bun.lock` with `bun install`, and complete verification. Commit and push the changes to `main`, then run:

```bash
gh workflow run release.yml --ref main
```

The manual `Release` workflow builds the library and runs `npm publish`. It publishes the version in `package.json`; it does not bump the version or create a Git tag. Check the workflow result and npm registry before announcing the release.
