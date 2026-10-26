# Decides how the iOS pods of react-native-nitro-google-auth get GoogleSignIn.
#
# Default: the `GoogleSignIn` CocoaPod, as before.
#
# Opt-in: set `$GoogleAuthUseSPM = true` in the Podfile (the Expo config plugin's
# `iosUseSwiftPackageManager` option writes it) to resolve GoogleSignIn through
# Swift Package Manager via React Native's `spm_dependency`. Use this together
# with `@react-native-firebase/*` 27+, which resolves Firebase 13 only through
# SPM: the CocoaPod would bring a second AppCheckCore and GoogleUtilities.
#
# SPM mode needs `use_frameworks! :linkage => :dynamic`, like React Native
# Firebase 27. It is opt-in rather than detected: a podspec cannot reliably see
# the Podfile's linkage, and switching static apps to SPM would break their link.

GOOGLE_AUTH_SIGN_IN_POD_REQUIREMENT = '~> 10.0' unless defined?(GOOGLE_AUTH_SIGN_IN_POD_REQUIREMENT)
GOOGLE_AUTH_SIGN_IN_SPM_URL = 'https://github.com/google/GoogleSignIn-iOS.git' unless defined?(GOOGLE_AUTH_SIGN_IN_SPM_URL)
# 10.1.0 is the first release that accepts AppCheckCore 12, which Firebase 13 requires.
GOOGLE_AUTH_SIGN_IN_SPM_MIN_VERSION = '10.1.0' unless defined?(GOOGLE_AUTH_SIGN_IN_SPM_MIN_VERSION)

# True only when the Podfile set `$GoogleAuthUseSPM = true`. The value is
# checked, not just `defined?`, so generated Podfiles can write `false`.
def google_auth_spm_requested?
  defined?($GoogleAuthUseSPM) && $GoogleAuthUseSPM == true
end

# True when GoogleSignIn resolves through SPM for this install. Falls back to the
# CocoaPod, with a warning, when `spm_dependency` is missing (React Native < 0.75).
def google_auth_use_spm?
  return false unless google_auth_spm_requested?
  return true if defined?(spm_dependency)

  unless defined?($GoogleAuthWarnedNoSPM) && $GoogleAuthWarnedNoSPM
    $GoogleAuthWarnedNoSPM = true
    Pod::UI.warn '[react-native-nitro-google-auth] `$GoogleAuthUseSPM = true` needs React Native 0.75+ ' \
                 '(`spm_dependency`). Using the GoogleSignIn CocoaPod instead.' if defined?(Pod::UI)
  end
  false
end

# Adds GoogleSignIn to `spec`, through SPM when `google_auth_use_spm?`, otherwise
# as a CocoaPod. Returns true when SPM was used.
def google_auth_sign_in_dependency(spec)
  unless google_auth_use_spm?
    spec.dependency 'GoogleSignIn', GOOGLE_AUTH_SIGN_IN_POD_REQUIREMENT
    return false
  end

  Pod::UI.puts "[react-native-nitro-google-auth] #{spec.name}: using SPM for GoogleSignIn" if defined?(Pod::UI)
  spm_dependency(spec,
                 url: GOOGLE_AUTH_SIGN_IN_SPM_URL,
                 requirement: { kind: 'upToNextMajorVersion', minimumVersion: GOOGLE_AUTH_SIGN_IN_SPM_MIN_VERSION },
                 products: ['GoogleSignIn'])
  true
end
