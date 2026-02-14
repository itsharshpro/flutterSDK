Pod::Spec.new do |s|
  s.name             = 'irctc_railtel_sdk'
  s.version          = '1.0.0'
  s.summary          = 'IRCTCRailtel Aadhaar Verification SDK for Flutter'
  s.description      = <<-DESC
  Flutter plugin for Aadhaar verification using Face RD biometric authentication
  and OTP verification. Supports both Android and iOS platforms.
                       DESC
  s.homepage         = 'https://irctcrailtel.in'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'IRCTCRailtel' => 'info@irctcrailtel.in' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '14.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version    = '5.0'
end
