import 'dart:async';
import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

/// Face RD Service for Flutter - Pure Dart Implementation
/// Handles launching the AadhaarFaceRD app on Android and iOS
class FaceRDService {
  // Android Face RD intent action
  static const String _faceRDActionAndroid = 'in.gov.uidai.rdservice.face.CAPTURE';
  
  // iOS Face RD URL scheme (per iOS API spec)
  static const String _faceRDSchemeIOS = 'FaceRDLib';
  
  // WADH value for KYC mode - must match server configuration
  static const String _wadhValue = 'DNhD9jrIYSEgfz5PNa1jruNKtp9/fw8mNyL8BcpAvPk=';
  
  // PID Options templates (without WADH - for non-KYC mode)
  static const String _pidOptionsProd = '<?xml version="1.0" encoding="UTF-8"?> <PidOptions ver="1.0" env="P"> <Opts format="0" pidVer="2.0" posh="UNKNOWN" /><Demo></Demo> <CustOpts><Param name="txnId" value="%s"/> </CustOpts> </PidOptions>';
  static const String _pidOptionsDev = '<?xml version="1.0" encoding="UTF-8"?> <PidOptions ver="1.0" env="PP"> <Opts format="0" pidVer="2.0" posh="UNKNOWN" /><Demo></Demo> <CustOpts><Param name="txnId" value="%s"/> </CustOpts> </PidOptions>';
  
  // PID Options with WADH (for KYC mode - required when kyc=true in API)
  static const String _pidOptionsKycProd = '<?xml version="1.0" encoding="UTF-8"?> <PidOptions ver="1.0" env="P"> <Opts format="0" pidVer="2.0" posh="UNKNOWN" wadh="$_wadhValue" /><Demo></Demo> <CustOpts><Param name="txnId" value="%s"/> </CustOpts> </PidOptions>';
  static const String _pidOptionsKycDev = '<?xml version="1.0" encoding="UTF-8"?> <PidOptions ver="1.0" env="PP"> <Opts format="0" pidVer="2.0" posh="UNKNOWN" wadh="$_wadhValue" /><Demo></Demo> <CustOpts><Param name="txnId" value="%s"/> </CustOpts> </PidOptions>';
  
  // For receiving results
  static const MethodChannel _channel = MethodChannel('irctc_railtel_sdk/face_rd');
  static Completer<String>? _captureCompleter;
  
  /// Initialize the service - set up method channel handler
  static void initialize() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }
  
  /// Check if Face RD app is available
  static Future<bool> isFaceRDAvailable() async {
    if (Platform.isAndroid) {
      try {
        final intent = AndroidIntent(
          action: _faceRDActionAndroid,
        );
        return await intent.canResolveActivity() ?? false;
      } catch (e) {
        return false;
      }
    } else if (Platform.isIOS) {
      try {
        final uri = Uri.parse('$_faceRDSchemeIOS://');
        return await canLaunchUrl(uri);
      } catch (e) {
        return false;
      }
    }
    return false;
  }
  
  /// Start face capture
  /// [isDemo] - true for pre-production environment
  /// [enableKyc] - true to use WADH for KYC mode (required for UKC transaction ID)
  /// Returns PID XML data on success, throws exception on error
  static Future<String> capture({
    required bool isDemo,
    bool enableKyc = true,
  }) async {
    if (_captureCompleter != null && !_captureCompleter!.isCompleted) {
      throw Exception('Face capture already in progress');
    }
    
    final txnId = const Uuid().v4();
    
    // Select PID Options based on environment and KYC setting
    String pidOptions;
    if (enableKyc) {
      pidOptions = isDemo ? _pidOptionsKycDev : _pidOptionsKycProd;
    } else {
      pidOptions = isDemo ? _pidOptionsDev : _pidOptionsProd;
    }
    final pidXml = pidOptions.replaceAll('%s', txnId);
    
    if (Platform.isAndroid) {
      return _captureAndroid(pidXml, txnId);
    } else if (Platform.isIOS) {
      return _captureIOS(pidXml, txnId);
    } else {
      throw Exception('Face RD is not supported on this platform');
    }
  }
  
  /// Android Face RD capture using android_intent_plus
  static Future<String> _captureAndroid(String pidXml, String txnId) async {
    _captureCompleter = Completer<String>();
    
    try {
      final intent = AndroidIntent(
        action: _faceRDActionAndroid,
        arguments: {
          'PID_OPTIONS': pidXml,
          'request': pidXml,
        },
        flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      
      // Check if Face RD app is available
      final canResolve = await intent.canResolveActivity() ?? false;
      if (!canResolve) {
        throw Exception('Face RD app not installed. Please install AadhaarFaceRD from Play Store.');
      }
      
      // Launch Face RD app
      await intent.launch();
      
      // Wait for result with timeout
      // Note: Getting results back requires native code or activity result handling
      // For now, we'll use a simplified approach with timeout
      return await _captureCompleter!.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          throw Exception('Face capture timed out. Please try again.');
        },
      );
    } catch (e) {
      _captureCompleter = null;
      if (e.toString().contains('timed out')) {
        rethrow;
      }
      throw Exception('Face capture failed: ${e.toString()}');
    }
  }
  
  /// iOS Face RD capture via URL Scheme (per iOS API spec)
  static Future<String> _captureIOS(String pidXml, String txnId) async {
    _captureCompleter = Completer<String>();
    
    try {
      // Encode the PID XML for URL
      final encodedPid = Uri.encodeComponent(pidXml);
      
      // iOS URL scheme format per iOS API spec:
      // FaceRDLib://in.gov.uidai.rdservice.face.CAPTURE?request=<encoded_pid_options>
      final urlString = '$_faceRDSchemeIOS://in.gov.uidai.rdservice.face.CAPTURE?request=$encodedPid';
      final uri = Uri.parse(urlString);
      
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        throw Exception('Failed to launch Face RD app. Please install AadhaarFaceRD from App Store.');
      }
      
      // Wait for callback with timeout
      return await _captureCompleter!.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          throw Exception('Face capture timed out');
        },
      );
    } catch (e) {
      _captureCompleter = null;
      rethrow;
    }
  }
  
  /// Handle method calls from native platforms (for receiving results)
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onFaceRDResult':
        final result = call.arguments as Map<dynamic, dynamic>?;
        if (result != null && _captureCompleter != null && !_captureCompleter!.isCompleted) {
          final pidData = result['pidData'] as String?;
          final error = result['error'] as String?;
          
          if (pidData != null && pidData.isNotEmpty) {
            if (pidData.contains('errCode="0"')) {
              _captureCompleter!.complete(pidData);
            } else {
              final errMatch = RegExp(r'errInfo="(.+?)"').firstMatch(pidData);
              _captureCompleter!.completeError(
                Exception(errMatch?.group(1) ?? 'Face capture failed'),
              );
            }
          } else if (error != null) {
            _captureCompleter!.completeError(Exception(error));
          } else {
            _captureCompleter!.completeError(Exception('Face capture cancelled'));
          }
          _captureCompleter = null;
        }
        break;
    }
  }
  
  /// Complete the capture with result (call from app when receiving result)
  static void completeCapture(String pidData) {
    if (_captureCompleter != null && !_captureCompleter!.isCompleted) {
      if (pidData.contains('errCode="0"')) {
        _captureCompleter!.complete(pidData);
      } else {
        final errMatch = RegExp(r'errInfo="(.+?)"').firstMatch(pidData);
        _captureCompleter!.completeError(
          Exception(errMatch?.group(1) ?? 'Face capture failed'),
        );
      }
      _captureCompleter = null;
    }
  }
  
  /// Cancel the pending capture
  static void cancelCapture([String? error]) {
    if (_captureCompleter != null && !_captureCompleter!.isCompleted) {
      _captureCompleter!.completeError(Exception(error ?? 'Face capture cancelled'));
      _captureCompleter = null;
    }
  }
  
  /// Handle URL callback (call from iOS AppDelegate or Android onNewIntent)
  /// Returns true if the URL was handled, false otherwise
  static bool handleCallback(Uri uri) {
    if (_captureCompleter == null || _captureCompleter!.isCompleted) {
      return false;
    }
    
    final queryParams = uri.queryParameters;
    final pidData = queryParams['response'] ?? 
                    queryParams['pid'] ?? 
                    queryParams['piddata'] ??
                    queryParams['PID_DATA'];
    final error = queryParams['error'] ?? queryParams['errorMessage'];
    
    if (pidData != null && pidData.isNotEmpty) {
      if (pidData.contains('errCode="0"')) {
        _captureCompleter!.complete(pidData);
      } else {
        final errMatch = RegExp(r'errInfo="(.+?)"').firstMatch(pidData);
        _captureCompleter!.completeError(
          Exception(errMatch?.group(1) ?? 'Face capture failed'),
        );
      }
    } else if (error != null) {
      _captureCompleter!.completeError(Exception(error));
    } else {
      _captureCompleter!.completeError(Exception('Face capture cancelled'));
    }
    
    _captureCompleter = null;
    return true;
  }
}
