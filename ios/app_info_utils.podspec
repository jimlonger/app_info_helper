Pod::Spec.new do |s|
  s.name             = 'app_info_utils'
  s.version          = '0.1.4'
  s.summary          = 'Unified native app, device, locale and identifier information.'
  s.description      = 'Flutter plugin for unified iOS and Android application, device, locale, timezone and identifier information.'
  s.homepage         = 'https://pub.dev/packages/app_info_utils'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'HearBaby' => 'support@hearbaby.app' }
  s.source           = { :path => '.' }
  s.source_files     = 'app_info_utils/Sources/app_info_utils/**/*'
  s.resource_bundles = {
    'app_info_utils_privacy' => ['app_info_utils/Sources/app_info_utils/PrivacyInfo.xcprivacy']
  }
  s.dependency       'Flutter'
  s.platform         = :ios, '15.0'
  s.swift_version = '5.0'
end
