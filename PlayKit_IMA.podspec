
Pod::Spec.new do |s|
    s.name              = 'PlayKit_IMA'
    s.version           = '0.0.2'
		s.author           = { 'Kaltura' => 'community@kaltura.com' }
		s.license          = { :type => 'AGPLv3', :text => 'AGPLv3' }
    s.summary           = 'PlayKit IMA Plugin'
    s.homepage          = 'https://github.com/kaltura/playkit-ios-ima'
	s.source           = { :git => 'https://github.com/kaltura/playkit-ios-ima.git', :tag => 'v' + s.version.to_s }
  s.source_files = '**/*.swift'
	s.ios.deployment_target = '8.0'
  s.xcconfig = { 
        'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES',
        'OTHER_LDFLAGS' => '$(inherited) -framework "GoogleInteractiveMediaAds"',
        'FRAMEWORK_SEARCH_PATHS' => '$(inherited) "${PODS_ROOT}"/**',
        'LIBRARY_SEARCH_PATHS' => '$(inherited) "${PODS_ROOT}"/**' 
    }
  s.dependency 'PlayKit/Core'
  s.dependency 'GoogleAds-IMA-iOS-SDK', '3.5.2'
end
