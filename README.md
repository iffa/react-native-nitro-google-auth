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
// Send result.idToken to your backend.

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
  - `idToken: string`
  - `providerUserId: string`
  - `email?: string`
  - `name?: string`
  - `photoUrl?: string`
- `GoogleAuth.signOut(): Promise<void>`

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
