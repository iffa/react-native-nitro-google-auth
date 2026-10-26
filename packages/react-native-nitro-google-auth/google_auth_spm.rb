# GoogleSignIn comes from CocoaPods unless the Podfile sets `$GoogleAuthUseSPM = true`.

GOOGLE_AUTH_SIGN_IN_POD_REQUIREMENT = '~> 10.0' unless defined?(GOOGLE_AUTH_SIGN_IN_POD_REQUIREMENT)
GOOGLE_AUTH_SIGN_IN_SPM_URL = 'https://github.com/google/GoogleSignIn-iOS.git' unless defined?(GOOGLE_AUTH_SIGN_IN_SPM_URL)
# First release that accepts AppCheckCore 12, which Firebase 13 requires.
GOOGLE_AUTH_SIGN_IN_SPM_MIN_VERSION = '10.1.0' unless defined?(GOOGLE_AUTH_SIGN_IN_SPM_MIN_VERSION)

def google_auth_use_spm?
  return false unless defined?($GoogleAuthUseSPM) && $GoogleAuthUseSPM == true
  return true if defined?(spm_dependency)

  unless defined?($GoogleAuthWarnedNoSPM) && $GoogleAuthWarnedNoSPM
    $GoogleAuthWarnedNoSPM = true
    Pod::UI.warn '[react-native-nitro-google-auth] `$GoogleAuthUseSPM = true` needs React Native 0.75+ ' \
                 '(`spm_dependency`). Using the GoogleSignIn CocoaPod instead.' if defined?(Pod::UI)
  end
  false
end

def google_auth_sign_in_dependency(spec)
  unless google_auth_use_spm?
    spec.dependency 'GoogleSignIn', GOOGLE_AUTH_SIGN_IN_POD_REQUIREMENT
    return
  end

  Pod::UI.puts "[react-native-nitro-google-auth] #{spec.name}: using SPM for GoogleSignIn" if defined?(Pod::UI)
  spm_dependency(spec,
                 url: GOOGLE_AUTH_SIGN_IN_SPM_URL,
                 requirement: { kind: 'upToNextMajorVersion', minimumVersion: GOOGLE_AUTH_SIGN_IN_SPM_MIN_VERSION },
                 products: ['GoogleSignIn'])
end
