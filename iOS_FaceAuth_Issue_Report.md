flutter/irctc_railtel_sdk/lib/src/face_rd_service.dart
```dart
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
  // Trying env="PP" (Pre-Production) since both "P" and "S" gave error 103.
  // The iOS Face RD app may be a pre-production build.
  // =====================================================

  static const String _iosPidOptionsProd =
      '<?xml version=\\"1.0\\" encoding=\\"UTF-8\\"?>'
      '<PidOptions ver=\\"1.0\\" env=\\"PP\\">'
      '<Opts format=\\"0\\" pidVer=\\"2.0\\" otp=\\"\\" />'
      '<CustOpts>'
      '<Param name=\\"txnId\\" value=\\"%s\\"/>'
      '</CustOpts>'
      '</PidOptions>';

  static const String _iosPidOptionsDev =
      '<?xml version=\\"1.0\\" encoding=\\"UTF-8\\"?>'
      '<PidOptions ver=\\"1.0\\" env=\\"PP\\">'
      '<Opts format=\\"0\\" pidVer=\\"2.0\\" otp=\\"\\" />'
      '<CustOpts>'
      '<Param name=\\"txnId\\" value=\\"%s\\"/>'
      '</CustOpts>'
      '</PidOptions>';

  static const String _iosPidOptionsKycProd =
      '<?xml version=\\"1.0\\" encoding=\\"UTF-8\\"?>'
      '<PidOptions ver=\\"1.0\\" env=\\"PP\\">'
      '<Opts format=\\"0\\" pidVer=\\"2.0\\" otp=\\"\\" wadh=\\"$_wadhValue\\" />'
      '<CustOpts>'
      '<Param name=\\"txnId\\" value=\\"%s\\"/>'
      '</CustOpts>'
      '</PidOptions>';

  static const String _iosPidOptionsKycDev =
      '<?xml version=\\"1.0\\" encoding=\\"UTF-8\\"?>'
      '<PidOptions ver=\\"1.0\\" env=\\"PP\\">'
      '<Opts format=\\"0\\" pidVer=\\"2.0\\" otp=\\"\\" wadh=\\"$_wadhValue\\" />'
      '<CustOpts>'
      '<Param name=\\"txnId\\" value=\\"%s\\"/>'
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
```

flutter/irctc_railtel_sdk/ios/Classes/IRCTCRailtelPlugin.swift
```swift
import Flutter
import UIKit

/**
 * IRCTCRailtelPlugin - Native iOS plugin for Face RD integration.
 *
 * Handles launching the UIDAI AadhaarFaceRD app via iOS URL Scheme
 * and receiving the PID data back when FaceRD returns to the calling app.
 *
 * iOS Face RD URL Scheme (per UIDAI iOS API Spec v1.3):
 * - Launch: FaceRDLib://in.gov.uidai.rdservice.face.CAPTURE?request=<encoded_pid_options>
 * - Response: Received in application(_:open:options:) when FaceRD returns
 *
 * IMPORTANT: Integrating apps must add to their Info.plist:
 * 1. LSApplicationQueriesSchemes: ["FaceRDLib"] (to check if FaceRD is installed)
 * 2. CFBundleURLTypes with their app's URL scheme (for FaceRD callback)
 */
public class IRCTCRailtelPlugin: NSObject, FlutterPlugin, FlutterApplicationLifeCycleDelegate {
    
    private static var channel: FlutterMethodChannel?
    private static var pendingResult: FlutterResult?
    private static var pendingTxnId: String?
    
    // MARK: - Plugin Registration
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        channel = FlutterMethodChannel(
            name: "irctc_railtel_sdk/face_rd",
            binaryMessenger: registrar.messenger()
        )
        let instance = IRCTCRailtelPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel!)
        registrar.addApplicationDelegate(instance)
    }
    
    // MARK: - Method Call Handler
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isFaceRDAvailable":
            checkFaceRDAvailable(result: result)
        case "launchFaceRD":
            guard let args = call.arguments as? [String: Any],
                  let pidOptions = args["pidOptions"] as? String else {
                result(FlutterError(
                    code: "INVALID_ARGS",
                    message: "pidOptions is required",
                    details: nil
                ))
                return
            }
            let txnId = args["txnId"] as? String
            launchFaceRD(pidOptions: pidOptions, txnId: txnId, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Face RD Availability Check
    
    /**
     * Check if AadhaarFaceRD app is installed on the device.
     * Requires LSApplicationQueriesSchemes to include "FaceRDLib" in Info.plist.
     */
    private func checkFaceRDAvailable(result: @escaping FlutterResult) {
        guard let url = URL(string: "FaceRDLib://") else {
            result(false)
            return
        }
        let available = UIApplication.shared.canOpenURL(url)
        NSLog("[IRCTCRailtelSDK] FaceRD available: %@", available ? "YES" : "NO")
        result(available)
    }
    
    // MARK: - Face RD Launch
    
    /**
     * Launch Face RD app via iOS URL Scheme.
     *
     * Per UIDAI iOS API Spec v1.3:
     * URL format: FaceRDLib://in.gov.uidai.rdservice.face.CAPTURE?request=<encoded_pid_options>
     *
     * CRITICAL ENCODING NOTE:
     * The PID XML value must be encoded SEPARATELY with a strict charset that
     * also encodes = ? & + / characters. Using .urlQueryAllowed on the entire
     * URL does NOT encode = and ? which are valid URL chars but break query
     * parameter parsing when they appear inside the request VALUE.
     *
     * Approach: Use Apple's URLComponents to build the URL properly.
     * URLComponents handles query value encoding automatically, encoding
     * = and & (which have special meaning in queries) while leaving
     * ? and / as-is. This produces the encoding pattern the Face RD app
     * may expect since it's the standard Apple URL construction method.
     */
    private func launchFaceRD(pidOptions: String, txnId: String?, result: @escaping FlutterResult) {
        if IRCTCRailtelPlugin.pendingResult != nil {
            result(FlutterError(
                code: "ALREADY_IN_PROGRESS",
                message: "Face capture already in progress",
                details: nil
            ))
            return
        }
        
        NSLog("[IRCTCRailtelSDK] ===== FACE RD LAUNCH START =====")
        NSLog("[IRCTCRailtelSDK] TxnId: %@", txnId ?? "nil")
        NSLog("[IRCTCRailtelSDK] PID Options XML (raw): %@", pidOptions)
        
        // Use URLComponents - Apple's standard URL builder.
        // URLComponents.queryItems automatically encodes query values:
        //   = → %3D (key-value separator)
        //   & → %26 (pair separator)
        //   < → %3C, > → %3E, " → %22, space → %20
        //   But leaves ? and / as-is (valid in query values per RFC 3986)
        guard var components = URLComponents(string: "FaceRDLib://in.gov.uidai.rdservice.face.CAPTURE") else {
            NSLog("[IRCTCRailtelSDK] ERROR: Failed to create URLComponents")
            result(FlutterError(
                code: "URL_ERROR",
                message: "Failed to create URL components",
                details: nil
            ))
            return
        }
        
        components.queryItems = [URLQueryItem(name: "request", value: pidOptions)]
        
        guard let url = components.url else {
            NSLog("[IRCTCRailtelSDK] ERROR: Failed to create URL from URLComponents")
            result(FlutterError(
                code: "URL_ERROR",
                message: "Failed to create Face RD URL",
                details: nil
            ))
            return
        }
        
        NSLog("[IRCTCRailtelSDK] URLComponents query: %@", components.percentEncodedQuery ?? "nil")
        NSLog("[IRCTCRailtelSDK] COMPLETE URL: %@", url.absoluteString)
        NSLog("[IRCTCRailtelSDK] URL length: %d", url.absoluteString.count)
        
        if UIApplication.shared.canOpenURL(url) {
            NSLog("[IRCTCRailtelSDK] canOpenURL: YES - launching Face RD")
            IRCTCRailtelPlugin.pendingResult = result
            IRCTCRailtelPlugin.pendingTxnId = txnId
            
            // Store txnId in UserDefaults (per UIDAI sample reference)
            if let txnId = txnId {
                UserDefaults.standard.set(txnId, forKey: "ReceivedTransactionID")
                UserDefaults.standard.synchronize()
            }
            
            UIApplication.shared.open(url, options: [:]) { success in
                NSLog("[IRCTCRailtelSDK] UIApplication.open completion: success=%@", success ? "YES" : "NO")
                if !success {
                    IRCTCRailtelPlugin.pendingResult = nil
                    IRCTCRailtelPlugin.pendingTxnId = nil
                    result(FlutterError(
                        code: "LAUNCH_ERROR",
                        message: "Failed to open Face RD app",
                        details: nil
                    ))
                }
            }
        } else {
            NSLog("[IRCTCRailtelSDK] canOpenURL: NO - Face RD not installed")
            result(FlutterError(
                code: "NOT_INSTALLED",
                message: "Face RD app not installed. Please install AadhaarFaceRD from App Store.",
                details: nil
            ))
        }
        
        NSLog("[IRCTCRailtelSDK] ===== FACE RD LAUNCH END =====")
    }
    
    // MARK: - URL Callback Handler
    
    /**
     * Handle URL callback from Face RD app.
     * FaceRD returns PID data via the calling app's URL scheme.
     */
    public func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        NSLog("[IRCTCRailtelSDK] application:open:options: called with URL: %@", String(url.absoluteString.prefix(500)))
        return handleIncomingURL(url)
    }
    
    // Also handle the older delegate method
    public func application(
        _ application: UIApplication,
        open url: URL,
        sourceApplication: String?,
        annotation: Any
    ) -> Bool {
        NSLog("[IRCTCRailtelSDK] application:open:sourceApplication: called with URL: %@", String(url.absoluteString.prefix(500)))
        return handleIncomingURL(url)
    }
    
    /**
     * Parse the incoming URL from FaceRD and extract PID data.
     *
     * Per UIDAI iOS API Spec, the response PidData includes:
     * - Resp element with errCode, errInfo
     * - DeviceInfo, Skey, Hmac, Data elements
     * - CustOpts with txnId and txnStatus
     */
    private func handleIncomingURL(_ url: URL) -> Bool {
        NSLog("[IRCTCRailtelSDK] handleIncomingURL called")
        NSLog("[IRCTCRailtelSDK] Full URL: %@", url.absoluteString)
        NSLog("[IRCTCRailtelSDK] URL scheme: %@", url.scheme ?? "nil")
        NSLog("[IRCTCRailtelSDK] URL host: %@", url.host ?? "nil")
        NSLog("[IRCTCRailtelSDK] URL query: %@", String((url.query ?? "nil").prefix(500)))
        
        guard let result = IRCTCRailtelPlugin.pendingResult else {
            NSLog("[IRCTCRailtelSDK] No pending result - ignoring URL")
            return false
        }
        
        IRCTCRailtelPlugin.pendingResult = nil
        
        // Try to extract PID data from the URL
        // Face RD may return data in different ways:
        // 1. As a query parameter (response=<pid_xml>)
        // 2. As the URL itself containing PID XML
        // 3. Via URL path/fragment
        
        var pidData: String?
        var error: String?
        
        // Method 1: Parse query parameters
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            let queryItems = components.queryItems ?? []
            NSLog("[IRCTCRailtelSDK] Query items count: %d", queryItems.count)
            
            for item in queryItems {
                NSLog("[IRCTCRailtelSDK] Query item: name='%@', value='%@'", item.name, String((item.value ?? "nil").prefix(200)))
                let name = item.name.lowercased()
                switch name {
                case "response", "pid", "piddata", "pid_data", "request":
                    pidData = item.value
                case "error", "errormessage", "errmessage", "errcode":
                    error = item.value
                default:
                    break
                }
            }
        }
        
        // Method 2: Check the full URL string for PID data
        if pidData == nil {
            let urlString = url.absoluteString.removingPercentEncoding ?? url.absoluteString
            NSLog("[IRCTCRailtelSDK] Checking full URL for PID data (decoded, first 500): %@", String(urlString.prefix(500)))
            
            if urlString.contains("<PidData") || urlString.contains("PidData") {
                // Try to extract PidData XML from the URL
                if let pidStart = urlString.range(of: "<PidData"),
                   let pidEnd = urlString.range(of: "</PidData>") {
                    let startIdx = pidStart.lowerBound
                    let endIdx = pidEnd.upperBound
                    pidData = String(urlString[startIdx..<endIdx])
                    NSLog("[IRCTCRailtelSDK] Extracted PidData from URL body")
                } else {
                    pidData = urlString
                    NSLog("[IRCTCRailtelSDK] Using full URL string as PID data")
                }
            } else if urlString.contains("errCode") {
                pidData = urlString
                NSLog("[IRCTCRailtelSDK] URL contains errCode, using as response")
            }
        }
        
        // Method 3: Check URL path for base64 response (per spec section 2.4.2)
        if pidData == nil {
            let path = url.path
            if !path.isEmpty && path != "/" {
                NSLog("[IRCTCRailtelSDK] Checking URL path: %@", String(path.prefix(200)))
                // Try base64 decode
                if let decoded = Data(base64Encoded: path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))),
                   let decodedStr = String(data: decoded, encoding: .utf8) {
                    pidData = decodedStr
                    NSLog("[IRCTCRailtelSDK] Decoded base64 PID from URL path")
                }
            }
        }
        
        NSLog("[IRCTCRailtelSDK] Final pidData: %@", pidData != nil ? String((pidData!).prefix(500)) : "nil")
        NSLog("[IRCTCRailtelSDK] Final error: %@", error ?? "nil")
        
        if let pid = pidData, !pid.isEmpty {
            if pid.contains("errCode=\"0\"") || pid.contains("errCode=&quot;0&quot;") {
                // Success - PID captured successfully
                NSLog("[IRCTCRailtelSDK] SUCCESS - PID captured")
                result(pid)
            } else {
                // Extract error from PID XML
                let pattern = "errInfo=\"(.+?)\""
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(
                    in: pid,
                    range: NSRange(pid.startIndex..., in: pid)
                   ),
                   let range = Range(match.range(at: 1), in: pid) {
                    let errMsg = String(pid[range])
                    NSLog("[IRCTCRailtelSDK] CAPTURE ERROR: %@", errMsg)
                    result(FlutterError(
                        code: "FACE_CAPTURE_ERROR",
                        message: errMsg,
                        details: pid
                    ))
                } else {
                    NSLog("[IRCTCRailtelSDK] CAPTURE FAILED - no errInfo found in PID")
                    result(FlutterError(
                        code: "FACE_CAPTURE_ERROR",
                        message: "Face capture failed",
                        details: pid
                    ))
                }
            }
        } else if let err = error {
            NSLog("[IRCTCRailtelSDK] FACE RD ERROR: %@", err)
            result(FlutterError(
                code: "FACE_RD_ERROR",
                message: err,
                details: nil
            ))
        } else {
            NSLog("[IRCTCRailtelSDK] NO RESPONSE - cancelled or empty")
            result(FlutterError(
                code: "CANCELLED",
                message: "Face capture cancelled or no response received",
                details: url.absoluteString
            ))
        }
        
        IRCTCRailtelPlugin.pendingTxnId = nil
        return true
    }
    
    // MARK: - App Lifecycle (for handling return from FaceRD without URL)
    
    /**
     * If the user returns to the app without FaceRD providing a URL callback,
     * we need to handle the timeout/cancellation.
     */
    public func applicationDidBecomeActive(_ application: UIApplication) {
        NSLog("[IRCTCRailtelSDK] applicationDidBecomeActive - pendingResult exists: %@",
              IRCTCRailtelPlugin.pendingResult != nil ? "YES" : "NO")
        
        // Give FaceRD a moment to deliver the URL callback
        // If no callback received within 3 seconds of becoming active,
        // the capture was likely cancelled
        if IRCTCRailtelPlugin.pendingResult != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                if let result = IRCTCRailtelPlugin.pendingResult {
                    NSLog("[IRCTCRailtelSDK] Timeout - no URL callback received after 3s, treating as cancelled")
                    IRCTCRailtelPlugin.pendingResult = nil
                    IRCTCRailtelPlugin.pendingTxnId = nil
                    result(FlutterError(
                        code: "CANCELLED",
                        message: "Face capture was cancelled or Face RD app did not return a response",
                        details: nil
                    ))
                }
            }
        }
    }
}
```
