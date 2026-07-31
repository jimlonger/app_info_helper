Pod::Spec.new do |s|
  s.name             = 'x_app_utils'
  s.version          = '0.1.5'
  s.summary          = 'Unified native app, device, locale and identifier information.'
  s.description      = 'Flutter plugin for unified iOS and Android application, device, locale, timezone and identifier information.'
  s.homepage         = 'https://pub.dev/packages/x_app_utils'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'HearBaby' => 'support@hearbaby.app' }
  s.source           = { :path => '.' }
  s.source_files     = 'x_app_utils/Sources/x_app_utils/**/*'
  s.resource_bundles = {
    'x_app_utils_privacy' => ['x_app_utils/Sources/x_app_utils/PrivacyInfo.xcprivacy']
  }
  s.dependency       'Flutter'
  s.platform         = :ios, '15.0'
  s.swift_version = '5.0'
end
