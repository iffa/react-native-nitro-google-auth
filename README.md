# react-native-nitro-google-auth

`react-native-nitro-google-auth` is a React Native package for implementing a "Sign in with Google" flow, built with Nitro modules.

[![Version](https://img.shields.io/npm/v/react-native-nitro-google-auth.svg)](https://www.npmjs.com/package/react-native-nitro-google-auth)
[![Downloads](https://img.shields.io/npm/dm/react-native-nitro-google-auth.svg)](https://www.npmjs.com/package/react-native-nitro-google-auth)
[![License](https://img.shields.io/npm/l/react-native-nitro-google-auth.svg)](https://github.com/iffa/react-native-nitro-google-auth/LICENSE)

## Install

```bash
# npm
npm install react-native-nitro-google-auth react-native-nitro-modules

# yarn
yarn add react-native-nitro-google-auth react-native-nitro-modules

# pnpm
pnpm add react-native-nitro-google-auth react-native-nitro-modules

# bun
bun add react-native-nitro-google-auth react-native-nitro-modules
```

## Google Cloud — OAuth clients

Create **Web**, **Android**, and **iOS** OAuth clients in **one** project: [Google Cloud Console → Clients](https://console.cloud.google.com/auth/clients).

| Client              | Purpose                                                                                                                                                                                                                  |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Web application** | Use its client ID as `webClientId` in `GoogleAuth.configure(...)`.                                                                                                                                                       |
| **Android**         | One client per package name + signing cert. **Package name** must match `applicationId`; **SHA-1** must match the keystore for the build you run. Wrong combo → runtime errors (e.g. credential / console setup errors). |
| **iOS**             | **Bundle ID** must match the app exactly or you get a runtime error. Use its client ID as `iosClientId`.                                                                                                                 |

## Usage

> [!IMPORTANT]  
> This library is by design headless. It does not provide a pre-built view for the sign-in button itself. You are expected to implement your own button that matches the [Sign in with Google Branding Guidelines](https://developers.google.com/identity/branding-guidelines).

```ts
import { GoogleAuth } from "react-native-nitro-google-auth";

// Must be called before signIn()
GoogleAuth.configure({
  iosClientId: "YOUR_IOS_CLIENT_ID.apps.googleusercontent.com",
  webClientId: "YOUR_WEB_CLIENT_ID.apps.googleusercontent.com",
});

const result = await GoogleAuth.signIn();
if (result.data) {
  // Send result.data.idToken to your backend.
} else if (result.error?.code !== "CANCELLED") {
  // Show guidance based on result.error.code. Native Android diagnostics
  // are available in result.error.android for error reporting.
}

await GoogleAuth.signOut();
```

## Expo

Add the Expo config plugin with `iosUrlScheme` set to the **reversed** iOS client ID (see above). The plugin registers the URL scheme in `Info.plist`.

`app.config.ts`:

```ts
export default {
  expo: {
    plugins: [
      [
        "react-native-nitro-google-auth",
        {
          iosUrlScheme: "com.googleusercontent.apps.123456789-abc",
        },
      ],
    ],
  },
};
```

## Bare React Native (iOS)

1. **URL scheme** — Add the reversed client ID to **CFBundleURLTypes**
2. **Open URL** — Implement the URL handler to forward to `GIDSignIn` so Google can complete the flow:

```swift
// AppDelegate.swift
import GoogleSignIn

func application(
  _ app: UIApplication,
  open url: URL,
  options: [UIApplication.OpenURLOptionsKey: Any] = [:]
) -> Bool {
  if GIDSignIn.sharedInstance.handle(url) {
    return true
  }
  return false
}
```

Merge this with your existing `application(_:open:options:)` if you already have one; forward to `GIDSignIn` before other handlers.

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

Cancellation, missing credentials, and Android provider configuration failures resolve with `result.error` and no `result.data`. Other failures reject the promise, so callers must also handle rejected promises.

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

The `PLAY_SERVICES_*` and `CREDENTIAL_PROVIDER_UNAVAILABLE` codes are Android-only. The library checks Play services after a provider configuration failure and preserves the native exception in `error.android`. It does not open settings, show alerts, or start updates. The app chooses the UI and translates its messages.

AndroidX can report "no provider dependencies found" when Play services is unavailable, even when the app includes the provider dependency. This library includes `credentials-play-services-auth`. The availability check uses the provider's minimum Play services version, currently `230815045` for AndroidX Credentials `1.6.0-rc02`.

Version `0.2.0` adds native bindings. Existing apps must rebuild their Android and iOS binaries before using it. An Expo OTA update alone cannot install these changes.

## Troubleshooting

| Symptom                                                                       | Checks                                                                                                                                                     |
| ----------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Android: `NoCredentialException`, `Developer console is not set up correctly` | `webClientId` is a **Web** client; Android OAuth client matches **package name + SHA-1**; same GCP project for all clients.                                |
| iOS sign-in fails                                                             | Bundle ID matches iOS OAuth client; URL scheme is the **reversed** client ID; `application(_:open:options:)` calls `GIDSignIn.sharedInstance.handle(url)`. |

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

For the iOS example, generate the native project with `bun run --filter example prebuild --platform ios --no-install`. From `packages/example/ios`, run `USE_FRAMEWORKS=static pod install`, then build `example.xcworkspace` in Xcode. Static frameworks provide the modules required by Google's Swift dependencies.

After changing the Nitro spec, run `bun run --filter react-native-nitro-google-auth codegen` and commit the generated bindings.

### Publishing

Update the library version in `packages/react-native-nitro-google-auth/package.json`, refresh `bun.lock` with `bun install`, and complete verification. Commit and push the changes to `main`, then run:

```bash
gh workflow run release.yml --ref main
```

The manual `Release` workflow builds the library and runs `npm publish`. It publishes the version in `package.json`; it does not bump the version or create a Git tag. Check the workflow result and npm registry before announcing the release.
