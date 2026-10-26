# Changelog

## Unreleased

### Added

- iOS: opt-in Swift Package Manager resolution of GoogleSignIn for apps using `@react-native-firebase/*` 27 (Firebase 13, SPM only) with dynamic frameworks.
  - Enable it with `$GoogleAuthUseSPM = true` in the Podfile, or with the Expo plugin option `iosUseSwiftPackageManager: true`.
  - It requires GoogleSignIn-iOS `>= 10.1.0, < 11.0.0` and React Native 0.75 or later. Older React Native versions fall back to the CocoaPod with a warning.
  - In this mode the Expo module no longer depends on the `GoogleSignIn`, `GoogleUtilities` or `RecaptchaInterop` pods. It forwards sign-in URLs to the GoogleSignIn copy linked by the `GoogleAuth` pod.
  - See the README and `docs/ios-spm.md`.

### Fixed

- `GoogleAuth.podspec`: `s.source` points at `iffa/react-native-nitro-google-auth`.

### Unchanged

- Apps that do not opt in keep the `GoogleSignIn` CocoaPod (`~> 10.0`) and the same podspec dependencies as before.
- React Native's CocoaPods-free `npx react-native spm` mode is not supported yet, because `react-native-nitro-modules` 0.37 has no `Package.swift`. See `docs/ios-spm.md`.
