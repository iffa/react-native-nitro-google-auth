require 'json'

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
  s.dependency 'GoogleSignIn', '~> 10.0'
  # AppCheckCore (through GoogleSignIn) imports these from Swift. Expo autolinking enables
  # modular headers only for direct dependencies, so a static library build needs them listed here.
  s.dependency 'GoogleUtilities'
  s.dependency 'RecaptchaInterop'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
  }

  s.source_files = 'ExpoAdapterGoogleAuth/**/*.{h,m,swift}'
end
