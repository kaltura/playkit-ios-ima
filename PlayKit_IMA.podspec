
suffix = '-dev'   # Dev mode
# suffix = ''       # Release

Pod::Spec.new do |s|
  s.name             = 'PlayKit_IMA'
  s.version          = '1.7.1' + suffix
  s.author           = { 'Kaltura' => 'community@kaltura.com' }
  s.license          = { :type => 'AGPLv3', :text => 'AGPLv3' }
  s.summary          = 'PlayKit IMA Plugin'
  s.homepage         = 'https://github.com/kaltura/playkit-ios-ima'
  s.source           = { :git => 'https://github.com/kaltura/playkit-ios-ima.git', :tag => 'v' + s.version.to_s }
  s.swift_version    = '5.0'
  
  s.ios.deployment_target = '9.0'
  s.tvos.deployment_target = '9.1'

  s.xcconfig = { 
        'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES',
        'OTHER_LDFLAGS' => '$(inherited) -framework "GoogleInteractiveMediaAds"',
        'FRAMEWORK_SEARCH_PATHS' => '$(inherited) "${PODS_ROOT}"/**',
        'LIBRARY_SEARCH_PATHS' => '$(inherited) "${PODS_ROOT}"/**' 
  }

  s.dependency 'PlayKit', '~> 3.11'
  s.dependency 'XCGLogger', '7.0.0'

  s.subspec 'iOS' do |sp|
    sp.source_files = 'Sources/*.swift'
    sp.dependency 'GoogleAds-IMA-iOS-SDK', '3.11.1'
  end

  s.subspec 'tvOS' do |sp|
    sp.source_files = 'Sources/*.swift'
    sp.dependency 'GoogleAds-IMA-tvOS-SDK', '4.2.1'
  end

  s.default_subspec = 'iOS'

end
