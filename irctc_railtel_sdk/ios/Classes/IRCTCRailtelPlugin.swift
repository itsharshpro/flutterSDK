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
        result(UIApplication.shared.canOpenURL(url))
    }
    
    // MARK: - Face RD Launch
    
    /**
     * Launch Face RD app via iOS URL Scheme.
     *
     * Per UIDAI iOS API Spec v1.3:
     * URL format: FaceRDLib://in.gov.uidai.rdservice.face.CAPTURE?request=<encoded_pid_options>
     * The entire URL must be percent-encoded.
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
        
        // Encode PID options for URL query parameter
        guard let encodedPid = pidOptions.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed
        ) else {
            result(FlutterError(
                code: "ENCODE_ERROR",
                message: "Failed to encode PID options",
                details: nil
            ))
            return
        }
        
        // Build the URL: FaceRDLib://action?request=<encoded_pid>
        let customUrl = "FaceRDLib://in.gov.uidai.rdservice.face.CAPTURE?request=\(encodedPid)"
        
        // Per iOS API spec: encode the entire URL
        guard let encodedUrl = customUrl.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed
        ),
              let url = URL(string: encodedUrl) else {
            result(FlutterError(
                code: "URL_ERROR",
                message: "Failed to create Face RD URL",
                details: nil
            ))
            return
        }
        
        if UIApplication.shared.canOpenURL(url) {
            IRCTCRailtelPlugin.pendingResult = result
            IRCTCRailtelPlugin.pendingTxnId = txnId
            
            // Store txnId in UserDefaults (per UIDAI sample reference)
            if let txnId = txnId {
                UserDefaults.standard.set(txnId, forKey: "ReceivedTransactionID")
                UserDefaults.standard.synchronize()
            }
            
            UIApplication.shared.open(url, options: [:]) { success in
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
            result(FlutterError(
                code: "NOT_INSTALLED",
                message: "Face RD app not installed. Please install AadhaarFaceRD from App Store.",
                details: nil
            ))
        }
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
        return handleIncomingURL(url)
    }
    
    // Also handle the older delegate method
    public func application(
        _ application: UIApplication,
        open url: URL,
        sourceApplication: String?,
        annotation: Any
    ) -> Bool {
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
        guard let result = IRCTCRailtelPlugin.pendingResult else {
            return false
        }
        
        IRCTCRailtelPlugin.pendingResult = nil
        
        // Parse query parameters from the callback URL
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            result(FlutterError(
                code: "PARSE_ERROR",
                message: "Failed to parse callback URL",
                details: url.absoluteString
            ))
            return true
        }
        
        let queryItems = components.queryItems ?? []
        var pidData: String?
        var error: String?
        
        for item in queryItems {
            let name = item.name.lowercased()
            switch name {
            case "response", "pid", "piddata", "pid_data":
                pidData = item.value
            case "error", "errormessage", "errmessage":
                error = item.value
            default:
                break
            }
        }
        
        // Also check if the URL path/host contains response data
        if pidData == nil {
            let urlString = url.absoluteString
            if urlString.contains("<PidData") || urlString.contains("errCode=") {
                pidData = urlString
            }
        }
        
        if let pid = pidData, !pid.isEmpty {
            if pid.contains("errCode=\"0\"") {
                // Success - PID captured successfully
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
                    result(FlutterError(
                        code: "FACE_CAPTURE_ERROR",
                        message: errMsg,
                        details: pid
                    ))
                } else {
                    result(FlutterError(
                        code: "FACE_CAPTURE_ERROR",
                        message: "Face capture failed",
                        details: pid
                    ))
                }
            }
        } else if let err = error {
            result(FlutterError(
                code: "FACE_RD_ERROR",
                message: err,
                details: nil
            ))
        } else {
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
        // Give FaceRD a moment to deliver the URL callback
        // If no callback received within 2 seconds of becoming active,
        // the capture was likely cancelled
        if IRCTCRailtelPlugin.pendingResult != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if let result = IRCTCRailtelPlugin.pendingResult {
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
