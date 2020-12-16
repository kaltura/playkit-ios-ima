
suffix = '.0000'   # Dev mode
# suffix = ''       # Release

Pod::Spec.new do |s|
  s.name             = 'PlayKit_IMA'
  s.version          = '1.9.0' + suffix
  s.author           = { 'Kaltura' => 'community@kaltura.com' }
  s.license          = { :type => 'AGPLv3', :text => 'AGPLv3' }
  s.summary          = 'PlayKit IMA Plugin'
  s.homepage         = 'https://github.com/kaltura/playkit-ios-ima'
  s.source           = { :git => 'https://github.com/kaltura/playkit-ios-ima.git', :tag => 'v' + s.version.to_s }
  s.swift_version    = '5.0'
  
  s.ios.deployment_target = '10.0'
  s.tvos.deployment_target = '10.0'

  s.dependency 'PlayKit', '~> 3.18'

  s.ios.source_files = 'Sources/*.swift', 'Sources/iOS/*.swift'
  s.tvos.source_files = 'Sources/*.swift', 'Sources/tvOS/*.swift'

  s.ios.dependency 'GoogleAds-IMA-iOS-SDK', '3.13.0'
  s.tvos.dependency 'GoogleAds-IMA-tvOS-SDK', '4.3.2'

  s.xcconfig = {
### The following is required for Xcode 12 (https://stackoverflow.com/questions/63607158/xcode-12-building-for-ios-simulator-but-linking-in-object-file-built-for-ios)
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64',
    'EXCLUDED_ARCHS[sdk=appletvsimulator*]' => 'arm64'
  }

end
