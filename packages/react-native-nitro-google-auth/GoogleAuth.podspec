require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "GoogleAuth"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => min_ios_version_supported }
  s.source       = { :git => "https://github.com/iffa/react-native-nitro-google-auth.git", :tag => "#{s.version}" }

  s.source_files = [
    # Implementation (Swift)
    "ios/**/*.{swift}",
    # Autolinking/Registration (Objective-C++)
    "ios/**/*.{m,mm}",
    # Implementation (C++ objects)
    "cpp/**/*.{hpp,cpp}",
  ]

  load 'nitrogen/generated/ios/GoogleAuth+autolinking.rb'
  add_nitrogen_files(s)

  s.dependency 'React-jsi'
  s.dependency 'React-callinvoker'
  # First release that accepts AppCheckCore 12, which Firebase 13 requires.
  spm_dependency(s,
                 url: 'https://github.com/google/GoogleSignIn-iOS.git',
                 requirement: { kind: 'upToNextMajorVersion', minimumVersion: '10.1.0' },
                 products: ['GoogleSignIn'])
  install_modules_dependencies(s)
end
