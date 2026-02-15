import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

/// Face RD Service for Flutter
///
/// Handles launching the UIDAI AadhaarFaceRD app on Android and iOS
/// through native platform channels.
///
/// Android: Uses native startActivityForResult to launch Face RD and get PID data back
/// iOS: Uses URL Scheme (FaceRDLib://) per UIDAI iOS API Spec v1.3
///
/// This service is used internally by the SDK. Integrators should not need to
/// call this directly - instead use [IRCTCRailtelSDK.startVerification].
class FaceRDService {
  /// Platform channel for native Face RD communication
  static const MethodChannel _channel =
      MethodChannel('irctc_railtel_sdk/face_rd');

  // WADH value for KYC mode - must match server configuration
  static const String _wadhValue =
      'DNhD9jrIYSEgfz5PNa1jruNKtp9/fw8mNyL8BcpAvPk=';

  // =====================================================
  // ANDROID PID Options (used with Intent extras - no URL encoding needed)
  // Matches the working native Android SDK format exactly
  // =====================================================

  static const String _androidPidOptionsProd =
      '<?xml version="1.0" encoding="UTF-8"?> '
      '<PidOptions ver="1.0" env="P"> '
      '<Opts format="0" pidVer="2.0" posh="UNKNOWN" />'
      '<Demo></Demo> '
      '<CustOpts>'
      '<Param name="txnId" value="%s"/> '
      '</CustOpts> '
      '</PidOptions>';

  static const String _androidPidOptionsDev =
      '<?xml version="1.0" encoding="UTF-8"?> '
      '<PidOptions ver="1.0" env="PP"> '
      '<Opts format="0" pidVer="2.0" posh="UNKNOWN" />'
      '<Demo></Demo> '
      '<CustOpts>'
      '<Param name="txnId" value="%s"/> '
      '</CustOpts> '
      '</PidOptions>';

  static const String _androidPidOptionsKycProd =
      '<?xml version="1.0" encoding="UTF-8"?> '
      '<PidOptions ver="1.0" env="P"> '
      '<Opts format="0" pidVer="2.0" posh="UNKNOWN" wadh="$_wadhValue" />'
      '<Demo></Demo> '
      '<CustOpts>'
      '<Param name="txnId" value="%s"/> '
      '</CustOpts> '
      '</PidOptions>';

  static const String _androidPidOptionsKycDev =
      '<?xml version="1.0" encoding="UTF-8"?> '
      '<PidOptions ver="1.0" env="PP"> '
      '<Opts format="0" pidVer="2.0" posh="UNKNOWN" wadh="$_wadhValue" />'
      '<Demo></Demo> '
      '<CustOpts>'
      '<Param name="txnId" value="%s"/> '
      '</CustOpts> '
      '</PidOptions>';

  // =====================================================
  // iOS PID Options (matching UIDAI iOS API Spec v1.3 Section 2.3)
  // - No posh attribute (reserved on iOS, error code 126)
  // - No <Demo> element (not in iOS spec)
  // - Has otp="" in Opts (per iOS spec)
  // - No trailing spaces between elements
  //
  // NOTE on env value:
  // The iOS Face RD app (UIDAI spec v1.3 - "WIP Draft Release") uses
  // env="S" (Staging). The production iOS Face RD app from App Store
  // is currently a staging/pre-production build and rejects env="P".
  // Android Face RD is separate and uses env="P"/"PP" correctly.
  // =====================================================

  static const String _iosPidOptionsProd =
      '<?xml version="1.0" encoding="UTF-8"?>'
      '<PidOptions ver="1.0" env="S">'
      '<Opts format="0" pidVer="2.0" otp="" />'
      '<CustOpts>'
      '<Param name="txnId" value="%s"/>'
      '</CustOpts>'
      '</PidOptions>';

  static const String _iosPidOptionsDev =
      '<?xml version="1.0" encoding="UTF-8"?>'
      '<PidOptions ver="1.0" env="S">'
      '<Opts format="0" pidVer="2.0" otp="" />'
      '<CustOpts>'
      '<Param name="txnId" value="%s"/>'
      '</CustOpts>'
      '</PidOptions>';

  static const String _iosPidOptionsKycProd =
      '<?xml version="1.0" encoding="UTF-8"?>'
      '<PidOptions ver="1.0" env="S">'
      '<Opts format="0" pidVer="2.0" otp="" wadh="$_wadhValue" />'
      '<CustOpts>'
      '<Param name="txnId" value="%s"/>'
      '</CustOpts>'
      '</PidOptions>';

  static const String _iosPidOptionsKycDev =
      '<?xml version="1.0" encoding="UTF-8"?>'
      '<PidOptions ver="1.0" env="S">'
      '<Opts format="0" pidVer="2.0" otp="" wadh="$_wadhValue" />'
      '<CustOpts>'
      '<Param name="txnId" value="%s"/>'
      '</CustOpts>'
      '</PidOptions>';

  /// Check if Face RD app is available on the device.
  ///
  /// On Android: Checks if any app can handle the CAPTURE intent.
  ///             Requires <queries> in AndroidManifest.xml (handled by SDK).
  /// On iOS: Checks if FaceRDLib:// URL scheme can be opened.
  ///         Requires LSApplicationQueriesSchemes in Info.plist.
  ///
  /// Returns true if Face RD is available, false otherwise.
  static Future<bool> isFaceRDAvailable() async {
    try {
      final result = await _channel.invokeMethod<bool>('isFaceRDAvailable');
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Start face capture using the Face RD app.
  ///
  /// [isDemo] - true for pre-production environment (env="PP"), false for production (env="P")
  /// [enableKyc] - true to include WADH in PID options (required for eKYC transactions)
  ///
  /// Returns PID XML data string on success.
  /// Throws [Exception] on error with descriptive message.
  ///
  /// Error codes from Face RD:
  /// - 0: Success
  /// - 100-129: Integration errors
  /// - 731: User abort
  /// - 736-738: Capture quality issues
  /// - 850-892: App/device issues
  /// - 901-904: Resource/network errors
  static Future<String> capture({
    required bool isDemo,
    bool enableKyc = true,
  }) async {
    final txnId = const Uuid().v4();

    // Select PID Options based on platform, environment, and KYC setting
    // iOS and Android have different PID XML formats per their respective specs
    String pidOptions;
    if (Platform.isIOS) {
      // iOS: Use UIDAI iOS API Spec v1.3 format
      if (enableKyc) {
        pidOptions = isDemo ? _iosPidOptionsKycDev : _iosPidOptionsKycProd;
      } else {
        pidOptions = isDemo ? _iosPidOptionsDev : _iosPidOptionsProd;
      }
    } else {
      // Android: Use working native Android SDK format
      if (enableKyc) {
        pidOptions = isDemo ? _androidPidOptionsKycDev : _androidPidOptionsKycProd;
      } else {
        pidOptions = isDemo ? _androidPidOptionsDev : _androidPidOptionsProd;
      }
    }
    final pidXml = pidOptions.replaceAll('%s', txnId);

    try {
      final result = await _channel.invokeMethod<String>('launchFaceRD', {
        'pidOptions': pidXml,
        'txnId': txnId,
      });

      if (result == null || result.isEmpty) {
        throw Exception('No response from Face RD');
      }

      return result;
    } on PlatformException catch (e) {
      // Map platform-specific errors to user-friendly messages
      switch (e.code) {
        case 'NOT_INSTALLED':
          throw Exception(
            'Face RD app not installed. Please install AadhaarFaceRD from '
            '${Platform.isIOS ? "App Store" : "Play Store"}.',
          );
        case 'CANCELLED':
          throw Exception('Face capture was cancelled');
        case 'FACE_CAPTURE_ERROR':
          throw Exception(e.message ?? 'Face capture failed');
        case 'NO_ACTIVITY':
          throw Exception('Unable to launch Face RD. Please try again.');
        case 'ALREADY_IN_PROGRESS':
          throw Exception('Face capture already in progress');
        default:
          throw Exception(e.message ?? 'Face capture failed: ${e.code}');
      }
    }
  }

  /// Handle URL callback from Face RD (iOS only).
  ///
  /// Call this from your AppDelegate's application(_:open:options:)
  /// if you need manual URL handling. The SDK plugin handles this
  /// automatically when registered as an application delegate.
  ///
  /// Returns true if the URL was handled by Face RD service.
  static bool handleCallback(Uri uri) {
    // This is now handled natively by the iOS plugin.
    // Kept for backward compatibility - integrators don't need to call this.
    return false;
  }
}
