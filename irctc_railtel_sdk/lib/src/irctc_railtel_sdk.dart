import 'package:flutter/material.dart';
import 'models.dart';
import 'verification_screen.dart';

/// IRCTCRailtel Verification SDK for Flutter
/// 
/// Usage:
/// ```dart
/// // Initialize
/// await IRCTCRailtelSDK.initialize();
/// 
/// // Start verification
/// final result = await IRCTCRailtelSDK.startVerification(context);
/// ```
class IRCTCRailtelSDK {
  static SDKConfig? _config;
  
  /// Initialize the SDK
  static Future<void> initialize({SDKConfig? config}) async {
    _config = config ?? SDKConfig();
  }
  
  /// Get current config
  static SDKConfig get config {
    if (_config == null) {
      throw Exception('IRCTCRailtelSDK not initialized. Call initialize() first.');
    }
    return _config!;
  }
  
  /// Start verification flow
  /// 
  /// Returns [VerificationResult] with success, failure, or cancelled status
  static Future<VerificationResult> startVerification(
    BuildContext context, {
    String? aadhaarNumber,
  }) async {
    if (_config == null) {
      return VerificationResult.failure(
        errorCode: 'NOT_INITIALIZED',
        message: 'SDK not initialized',
      );
    }
    
    final result = await Navigator.of(context).push<VerificationResult>(
      MaterialPageRoute(
        builder: (context) => VerificationScreen(
          aadhaarNumber: aadhaarNumber,
        ),
      ),
    );
    
    return result ?? VerificationResult.cancelled();
  }
}
