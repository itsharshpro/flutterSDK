import 'package:flutter/services.dart';

/// Android platform implementation stub
/// This is a pure Dart package, so we provide a stub implementation
class IRCTCRailtelSDKAndroid {
  static const MethodChannel _channel = MethodChannel('irctc_railtel_sdk');

  static void registerWith() {
    // This is a pure Dart package - no native Android code needed
    // The SDK uses android_intent_plus and url_launcher for platform interactions
    // This stub exists only to satisfy Flutter's plugin registration system
  }
}
