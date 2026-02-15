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
     * Without this, the Face RD app's URL parser splits on the first unencoded =
     * and only receives a partial XML, causing Error 103 (env value not found).
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
        
        // STEP 1: Encode the PID XML value with RFC 3986 unreserved characters ONLY.
        // This ensures ALL special chars (= ? & + / < > " : ; etc.) in the XML
        // are percent-encoded, preventing the URL parser from misinterpreting them
        // as URL structural characters.
        let unreserved = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        guard let encodedPidValue = pidOptions.addingPercentEncoding(withAllowedCharacters: unreserved) else {
            NSLog("[IRCTCRailtelSDK] ERROR: Failed to percent-encode PID XML value")
            result(FlutterError(
                code: "ENCODE_ERROR",
                message: "Failed to encode PID XML",
                details: nil
            ))
            return
        }
        
        // STEP 2: Build the URL with the properly encoded value.
        // The URL structure (scheme, host, ?, request=) uses literal characters.
        // The value portion is fully encoded from step 1.
        let urlString = "FaceRDLib://in.gov.uidai.rdservice.face.CAPTURE?request=\(encodedPidValue)"
        
        NSLog("[IRCTCRailtelSDK] Encoded PID value length: %d", encodedPidValue.count)
        NSLog("[IRCTCRailtelSDK] Full URL string length: %d", urlString.count)
        // Log the COMPLETE URL for debugging (no truncation)
        NSLog("[IRCTCRailtelSDK] COMPLETE URL: %@", urlString)
        
        // STEP 3: Create URL directly - no additional encoding needed since
        // the URL structure is clean and the value is fully encoded.
        guard let url = URL(string: urlString) else {
            NSLog("[IRCTCRailtelSDK] ERROR: Failed to create URL from string")
            result(FlutterError(
                code: "URL_ERROR",
                message: "Failed to create Face RD URL",
                details: nil
            ))
            return
        }
        
        NSLog("[IRCTCRailtelSDK] Final URL: %@", url.absoluteString)
        
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
