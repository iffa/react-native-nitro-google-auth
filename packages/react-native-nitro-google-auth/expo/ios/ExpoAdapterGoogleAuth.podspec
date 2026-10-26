require 'json'
require File.expand_path('../../google_auth_spm', __dir__)

package = JSON.parse(File.read(File.join(__dir__, '..', '..', 'package.json')))

Pod::Spec.new do |s|
  s.name = 'ExpoAdapterGoogleAuth'
  s.version = package['version']
  s.summary = package['description']
  s.description = package['description']
  s.license = package['license']
  s.author = package['author']
  s.homepage = package['homepage']
  s.platform = :ios, '15.1'
  s.swift_version = '5.4'
  s.source = { :git => package['repository'], :tag => "#{s.version}" }
  s.static_framework = true

  s.dependency 'ExpoModulesCore'
  s.dependency 'React-Core'

  pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
  }

  if google_auth_use_spm?
    # GoogleSignIn is linked once, into the GoogleAuth pod. A second copy here would
    # carry its own GIDSignIn.sharedInstance, so the adapter forwards URLs to that one
    # through the Objective-C runtime and does not import GoogleSignIn at all.
    pod_target_xcconfig['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = '$(inherited) GOOGLE_AUTH_SPM'
  else
    s.dependency 'GoogleSignIn', GOOGLE_AUTH_SIGN_IN_POD_REQUIREMENT
    # AppCheckCore (through GoogleSignIn) imports these from Swift. Expo autolinking enables
    # modular headers only for direct dependencies, so a static library build needs them listed here.
    s.dependency 'GoogleUtilities'
    s.dependency 'RecaptchaInterop'
  end

  s.pod_target_xcconfig = pod_target_xcconfig

  s.source_files = 'ExpoAdapterGoogleAuth/**/*.{h,m,swift}'
end
