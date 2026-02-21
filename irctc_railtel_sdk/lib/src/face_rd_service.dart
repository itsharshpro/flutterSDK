import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

class FaceRDService {
  static const MethodChannel _channel =
      MethodChannel('irctc_railtel_sdk/face_rd');

  static const String _wadhValue =
      'DNhD9jrIYSEgfz5PNa1jruNKtp9/fw8mNyL8BcpAvPk=';

  // =====================================================
  // ANDROID PID Options - matches native Android SDK exactly
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
  // iOS PID Options - per UIDAI iOS API Spec v1.3
  // NO callback param — Face RD returns via URL scheme automatically.
  // callback param was CAUSING the Face RD to try HTTP POST which timed out.
  // Added timeout="60000" (60s) to give more processing time.
  // =====================================================

  static String _iosPidOptionsKycProd(String txnId) =>
      '<?xml version="1.0" encoding="UTF-8"?>'
      '<PidOptions ver="1.0" env="P">'
      '<Opts format="0" pidVer="2.0" timeout="60000" otp="" wadh="$_wadhValue" />'
      '<CustOpts>'
      '<Param name="txnId" value="$txnId"/>'
      '<Param name="callback" value="irctcrailtel://capture/response"/>'
      '</CustOpts>'
      '</PidOptions>';

  static String _iosPidOptionsKycDev(String txnId) =>
      '<?xml version="1.0" encoding="UTF-8"?>'
      '<PidOptions ver="1.0" env="PP">'
      '<Opts format="0" pidVer="2.0" timeout="60000" otp="" wadh="$_wadhValue" />'
      '<CustOpts>'
      '<Param name="txnId" value="$txnId"/>'
      '<Param name="callback" value="irctcrailtel://capture/response"/>'
      '</CustOpts>'
      '</PidOptions>';

  static String _iosPidOptionsProd(String txnId) =>
      '<?xml version="1.0" encoding="UTF-8"?>'
      '<PidOptions ver="1.0" env="P">'
      '<Opts format="0" pidVer="2.0" timeout="60000" otp="" />'
      '<CustOpts>'
      '<Param name="txnId" value="$txnId"/>'
      '<Param name="callback" value="irctcrailtel://capture/response"/>'
      '</CustOpts>'
      '</PidOptions>';

  static String _iosPidOptionsDev(String txnId) =>
      '<?xml version="1.0" encoding="UTF-8"?>'
      '<PidOptions ver="1.0" env="PP">'
      '<Opts format="0" pidVer="2.0" timeout="60000" otp="" />'
      '<CustOpts>'
      '<Param name="txnId" value="$txnId"/>'
      '<Param name="callback" value="irctcrailtel://capture/response"/>'
      '</CustOpts>'
      '</PidOptions>';

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

  static Future<String> capture({
    required bool isDemo,
    bool enableKyc = true,
  }) async {
    final txnId = const Uuid().v4();

    String pidXml;
    if (Platform.isIOS) {
      if (enableKyc) {
        pidXml = isDemo ? _iosPidOptionsKycDev(txnId) : _iosPidOptionsKycProd(txnId);
      } else {
        pidXml = isDemo ? _iosPidOptionsDev(txnId) : _iosPidOptionsProd(txnId);
      }
    } else {
      String pidOptions;
      if (enableKyc) {
        pidOptions = isDemo ? _androidPidOptionsKycDev : _androidPidOptionsKycProd;
      } else {
        pidOptions = isDemo ? _androidPidOptionsDev : _androidPidOptionsProd;
      }
      pidXml = pidOptions.replaceAll('%s', txnId);
    }

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

  static bool handleCallback(Uri uri) {
    return false;
  }
}
