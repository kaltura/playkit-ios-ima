
suffix = '-dev'   # Dev mode
#suffix = ''       # Release

Pod::Spec.new do |s|
  s.name             = 'PlayKit_IMA'
  s.version          = '1.3.0' + suffix
  s.author           = { 'Kaltura' => 'community@kaltura.com' }
  s.license          = { :type => 'AGPLv3', :text => 'AGPLv3' }
  s.summary          = 'PlayKit IMA Plugin'
  s.homepage         = 'https://github.com/kaltura/playkit-ios-ima'
  s.source           = { :git => 'https://github.com/kaltura/playkit-ios-ima.git', :tag => 'v' + s.version.to_s }
  s.swift_version    = '4.0'
  
  s.ios.deployment_target = '9.0'
  
  s.dependency 'PlayKit', '~> 3.8.0' + suffix
  s.dependency 'XCGLogger', '~> 6.1.0'
  
  s.subspec 'iOS' do |sp|
    sp.source_files = 'Common/*.swift', 'IMA/*.swift', 'IMADAI/*.swift'
    
    sp.dependency 'GoogleAds-IMA-iOS-SDK', '3.8.1'
    
    sp.xcconfig = {
      'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES',
      'OTHER_LDFLAGS' => '$(inherited) -framework "GoogleInteractiveMediaAds"',
      'FRAMEWORK_SEARCH_PATHS' => '$(inherited) "${PODS_ROOT}"/**',
      'LIBRARY_SEARCH_PATHS' => '$(inherited) "${PODS_ROOT}"/**'
    }
  end
  
  s.subspec 'tvOS' do |sp|
    sp.source_files = 'Common/*.swift', 'IMADAI/**'
    
    sp.tvos.deployment_target = '9.0'
    sp.vendored_frameworks = 'IMADAI/tvOS/InteractiveMediaAds.framework'
    
    sp.xcconfig = {
      'OTHER_LDFLAGS' => '$(inherited) -framework "GoogleInteractiveMediaAds"',
      'FRAMEWORK_SEARCH_PATHS' => '$(inherited) "${PODS_ROOT}"/**',
      'LIBRARY_SEARCH_PATHS' => '$(inherited) "${PODS_ROOT}"/**'
    }
  end
  
  s.default_subspec = 'iOS'
end

