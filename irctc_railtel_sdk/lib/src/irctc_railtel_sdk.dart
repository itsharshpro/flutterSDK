import 'package:flutter/material.dart';
import 'models.dart';
import 'verification_screen.dart';

/// IRCTCRailtel Verification SDK for Flutter
/// 
/// Flow (matching native Android SDK):
/// 1. Aadhaar Entry (or pre-filled)
/// 2. Demographics Entry (name, DOB, gender)
/// 3. Demographics Verification (API call)
/// 4. Method Selection (OTP or Face RD) - if enableOtp is true
/// 5. Verification (OTP or Face Auth)
/// 6. Result
/// 
/// Usage:
/// ```dart
/// // Initialize
/// await IRCTCRailtelSDK.initialize();
/// 
/// // Start verification (SDK collects all data)
/// final result = await IRCTCRailtelSDK.startVerification(context);
/// 
/// // Or start with pre-filled data (like native Android SDK)
/// final result = await IRCTCRailtelSDK.startVerification(
///   context,
///   aadhaarNumber: '123456789012',
///   name: 'John Doe',
///   dob: '1990-01-15',
///   gender: 'M',
/// );
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
  /// Optionally provide [aadhaarNumber], [name], [dob], [gender] to pre-fill data.
  /// If all four are provided, the SDK skips data entry and goes directly to
  /// demographics verification (matching native Android SDK behavior).
  /// 
  /// Returns [VerificationResult] with success, failure, or cancelled status
  static Future<VerificationResult> startVerification(
    BuildContext context, {
    String? aadhaarNumber,
    String? name,
    String? dob,
    String? gender,
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
          name: name,
          dob: dob,
          gender: gender,
        ),
      ),
    );
    
    return result ?? VerificationResult.cancelled();
  }
}
