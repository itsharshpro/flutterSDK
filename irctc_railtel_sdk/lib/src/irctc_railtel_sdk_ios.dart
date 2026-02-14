import 'package:flutter/services.dart';

/// iOS platform implementation stub
/// This is a pure Dart package, so we provide a stub implementation
class IRCTCRailtelSDKIOS {
  static const MethodChannel _channel = MethodChannel('irctc_railtel_sdk');

  static void registerWith() {
    // This is a pure Dart package - no native iOS code needed
    // The SDK uses url_launcher for platform interactions
    // This stub exists only to satisfy Flutter's plugin registration system
  }
}
