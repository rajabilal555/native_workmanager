#
# Native WorkManager for Flutter - iOS
# Uses KMP WorkManager as the native engine
#
Pod::Spec.new do |s|
  s.name             = 'native_workmanager'
  s.version          = '1.3.0'
  s.summary          = 'Background task manager for Flutter using platform-native APIs.'
  s.description      = <<-DESC
Native WorkManager is a Flutter plugin that provides native background task scheduling
using Kotlin Multiplatform. It runs tasks without waking up the Flutter Engine,
saving battery and memory.

Features:
- Zero Flutter Engine overhead for native workers
- Task chains (A → B → C workflows)
- Auto iOS configuration (reads Info.plist)
- Built-in HTTP workers (request, upload, download, sync)
                       DESC
  s.homepage         = 'https://github.com/brewkits/native_workmanager'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'Brewkits' => 'vietnguyentuan@gmail.com' }
  s.source           = { :path => '.' }
  # Sources now live in the SPM-compatible location (shared with Package.swift)
  s.source_files     = 'native_workmanager/Sources/native_workmanager/**/*.{swift,h,m}'
  s.dependency 'Flutter'
  s.platform         = :ios, '14.0'

  # Ensure Swift files are included
  s.ios.deployment_target = '14.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
  s.swift_version = '5.0'

  # KMP WorkManager Framework (kmpworkmanager v2.5.1)
  # Downloaded from GitHub Releases to stay under the pub.dev 100 MB package limit.
  s.prepare_command = <<-CMD
    set -e
    if [ ! -d "Frameworks/KMPWorkManager.xcframework" ]; then
      echo "Downloading KMPWorkManager.xcframework v2.5.1..."
      mkdir -p Frameworks
      curl -L --retry 3 -o /tmp/KMPWorkManager.xcframework.zip \
        "https://github.com/brewkits/native_workmanager/releases/download/v1.3.0/KMPWorkManager.xcframework.zip"
      cd Frameworks && unzip -o /tmp/KMPWorkManager.xcframework.zip && cd ..
      rm -f /tmp/KMPWorkManager.xcframework.zip
    fi
  CMD
  s.vendored_frameworks = 'Frameworks/KMPWorkManager.xcframework'

  # Privacy manifest for background task APIs (iOS 17+ App Store requirement)
  s.resource_bundles = {'native_workmanager_privacy' => ['native_workmanager/Sources/native_workmanager/PrivacyInfo.xcprivacy']}
end
