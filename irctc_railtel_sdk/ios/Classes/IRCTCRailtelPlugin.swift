import Flutter
import UIKit

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
        
        // Log diagnostic info at startup
        instance.logDiagnostics()
    }
    
    // MARK: - Diagnostics
    
    private func logDiagnostics() {
        NSLog("[IRCTCRailtelSDK] ===== DIAGNOSTICS START =====")
        
        // Log registered URL schemes (CFBundleURLTypes)
        if let urlTypes = Bundle.main.infoDictionary?["CFBundleURLTypes"] as? [[String: Any]] {
            NSLog("[IRCTCRailtelSDK] Registered URL Types count: %d", urlTypes.count)
            for (i, urlType) in urlTypes.enumerated() {
                let identifier = urlType["CFBundleURLName"] as? String ?? "none"
                let schemes = urlType["CFBundleURLSchemes"] as? [String] ?? []
                let role = urlType["CFBundleTypeRole"] as? String ?? "none"
                NSLog("[IRCTCRailtelSDK] URL Type[%d]: identifier=%@, role=%@, schemes=%@", i, identifier, role, schemes.joined(separator: ", "))
            }
        } else {
            NSLog("[IRCTCRailtelSDK] WARNING: No CFBundleURLTypes found in Info.plist!")
        }
        
        // Log queried URL schemes (LSApplicationQueriesSchemes)
        if let queriedSchemes = Bundle.main.infoDictionary?["LSApplicationQueriesSchemes"] as? [String] {
            NSLog("[IRCTCRailtelSDK] LSApplicationQueriesSchemes: %@", queriedSchemes.joined(separator: ", "))
        } else {
            NSLog("[IRCTCRailtelSDK] WARNING: No LSApplicationQueriesSchemes found in Info.plist!")
        }
        
        // Check if our callback scheme can be opened
        if let callbackUrl = URL(string: "irctcrailtel://test") {
            let canOpen = UIApplication.shared.canOpenURL(callbackUrl)
            NSLog("[IRCTCRailtelSDK] Can open own callback scheme 'irctcrailtel://': %@", canOpen ? "YES" : "NO")
        }
        
        // Check Face RD availability
        if let faceRDUrl = URL(string: "FaceRDLib://") {
            let canOpen = UIApplication.shared.canOpenURL(faceRDUrl)
            NSLog("[IRCTCRailtelSDK] Can open FaceRDLib://: %@", canOpen ? "YES" : "NO")
        }
        
        // Log bundle identifier
        NSLog("[IRCTCRailtelSDK] Bundle ID: %@", Bundle.main.bundleIdentifier ?? "unknown")
        
        // Log iOS version
        NSLog("[IRCTCRailtelSDK] iOS version: %@", UIDevice.current.systemVersion)
        
        NSLog("[IRCTCRailtelSDK] ===== DIAGNOSTICS END =====")
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
        NSLog("[IRCTCRailtelSDK] PID Options XML (raw, complete): %@", pidOptions)
        NSLog("[IRCTCRailtelSDK] PID XML length: %d", pidOptions.count)
        
        // Log callback and wadh presence
        NSLog("[IRCTCRailtelSDK] Has callback param: %@", pidOptions.contains("callback") ? "YES" : "NO")
        NSLog("[IRCTCRailtelSDK] Has wadh param: %@", pidOptions.contains("wadh") ? "YES" : "NO")
        NSLog("[IRCTCRailtelSDK] Has timeout param: %@", pidOptions.contains("timeout") ? "YES" : "NO")
        
        // Extract env value for logging
        if let envRange = pidOptions.range(of: "env=\"") {
            let envStart = pidOptions.index(envRange.upperBound, offsetBy: 0)
            if let envEnd = pidOptions[envStart...].firstIndex(of: "\"") {
                let envValue = String(pidOptions[envStart..<envEnd])
                NSLog("[IRCTCRailtelSDK] ENV value: '%@'", envValue)
            }
        }
        
        // Per UIDAI sample: build raw URL then encode entire thing with .urlQueryAllowed
        let customUrl = "FaceRDLib://in.gov.uidai.rdservice.face.CAPTURE?request=\(pidOptions)"
        NSLog("[IRCTCRailtelSDK] Raw URL length: %d", customUrl.count)
        
        guard let encodedUrl = customUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            NSLog("[IRCTCRailtelSDK] ERROR: Percent encoding failed")
            result(FlutterError(code: "URL_ERROR", message: "Failed to encode URL", details: nil))
            return
        }
        
        NSLog("[IRCTCRailtelSDK] Encoded URL (complete): %@", encodedUrl)
        NSLog("[IRCTCRailtelSDK] Encoded URL length: %d", encodedUrl.count)
        
        guard let url = URL(string: encodedUrl) else {
            NSLog("[IRCTCRailtelSDK] ERROR: URL creation failed from encoded string")
            result(FlutterError(code: "URL_ERROR", message: "Failed to create URL", details: nil))
            return
        }
        
        NSLog("[IRCTCRailtelSDK] URL object created successfully")
        NSLog("[IRCTCRailtelSDK] URL.scheme: %@", url.scheme ?? "nil")
        NSLog("[IRCTCRailtelSDK] URL.host: %@", url.host ?? "nil")
        NSLog("[IRCTCRailtelSDK] URL.path: %@", url.path)
        NSLog("[IRCTCRailtelSDK] URL.query (first 300): %@", String((url.query ?? "nil").prefix(300)))
        
        let canOpen = UIApplication.shared.canOpenURL(url)
        NSLog("[IRCTCRailtelSDK] canOpenURL: %@", canOpen ? "YES" : "NO")
        
        if canOpen {
            IRCTCRailtelPlugin.pendingResult = result
            IRCTCRailtelPlugin.pendingTxnId = txnId
            
            if let txnId = txnId {
                UserDefaults.standard.set(txnId, forKey: "ReceivedTransactionID")
                UserDefaults.standard.synchronize()
                NSLog("[IRCTCRailtelSDK] Stored txnId in UserDefaults: %@", txnId)
            }
            
            NSLog("[IRCTCRailtelSDK] Calling UIApplication.shared.open...")
            UIApplication.shared.open(url, options: [:]) { success in
                NSLog("[IRCTCRailtelSDK] UIApplication.open completion: success=%@", success ? "YES" : "NO")
                if !success {
                    NSLog("[IRCTCRailtelSDK] ERROR: UIApplication.open returned false")
                    IRCTCRailtelPlugin.pendingResult = nil
                    IRCTCRailtelPlugin.pendingTxnId = nil
                    result(FlutterError(code: "LAUNCH_ERROR", message: "Failed to open Face RD app", details: nil))
                }
            }
        } else {
            NSLog("[IRCTCRailtelSDK] Face RD not installed or FaceRDLib not in LSApplicationQueriesSchemes")
            result(FlutterError(code: "NOT_INSTALLED", message: "Face RD app not installed", details: nil))
        }
        
        NSLog("[IRCTCRailtelSDK] ===== FACE RD LAUNCH END =====")
    }
    
    // MARK: - URL Callback Handler
    
    public func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        NSLog("[IRCTCRailtelSDK] ===== URL CALLBACK RECEIVED =====")
        NSLog("[IRCTCRailtelSDK] URL scheme: %@", url.scheme ?? "nil")
        NSLog("[IRCTCRailtelSDK] Full URL (first 1000): %@", String(url.absoluteString.prefix(1000)))
        NSLog("[IRCTCRailtelSDK] Source app: %@", options[.sourceApplication] as? String ?? "unknown")
        return handleIncomingURL(url)
    }
    
    public func application(
        _ application: UIApplication,
        open url: URL,
        sourceApplication: String?,
        annotation: Any
    ) -> Bool {
        NSLog("[IRCTCRailtelSDK] ===== URL CALLBACK RECEIVED (legacy) =====")
        NSLog("[IRCTCRailtelSDK] URL scheme: %@", url.scheme ?? "nil")
        NSLog("[IRCTCRailtelSDK] Source app: %@", sourceApplication ?? "unknown")
        return handleIncomingURL(url)
    }
    
    private func handleIncomingURL(_ url: URL) -> Bool {
        NSLog("[IRCTCRailtelSDK] handleIncomingURL called")
        NSLog("[IRCTCRailtelSDK] Full URL: %@", url.absoluteString)
        NSLog("[IRCTCRailtelSDK] URL decoded: %@", url.absoluteString.removingPercentEncoding ?? "decode failed")
        NSLog("[IRCTCRailtelSDK] URL scheme: %@", url.scheme ?? "nil")
        NSLog("[IRCTCRailtelSDK] URL host: %@", url.host ?? "nil")
        NSLog("[IRCTCRailtelSDK] URL path: %@", url.path)
        NSLog("[IRCTCRailtelSDK] URL query (first 500): %@", String((url.query ?? "nil").prefix(500)))
        NSLog("[IRCTCRailtelSDK] URL fragment: %@", url.fragment ?? "nil")
        NSLog("[IRCTCRailtelSDK] pendingResult exists: %@", IRCTCRailtelPlugin.pendingResult != nil ? "YES" : "NO")
        NSLog("[IRCTCRailtelSDK] pendingTxnId: %@", IRCTCRailtelPlugin.pendingTxnId ?? "nil")
        
        guard let result = IRCTCRailtelPlugin.pendingResult else {
            NSLog("[IRCTCRailtelSDK] No pending result - ignoring URL callback")
            return false
        }
        
        IRCTCRailtelPlugin.pendingResult = nil
        
        var pidData: String?
        var error: String?
        
        // Method 1: Parse query parameters
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            let queryItems = components.queryItems ?? []
            NSLog("[IRCTCRailtelSDK] Query items count: %d", queryItems.count)
            
            for item in queryItems {
                NSLog("[IRCTCRailtelSDK] Query item: name='%@', value(first 300)='%@'", item.name, String((item.value ?? "nil").prefix(300)))
                let name = item.name.lowercased()
                switch name {
                case "response", "pid", "piddata", "pid_data", "request":
                    pidData = item.value
                    NSLog("[IRCTCRailtelSDK] Found PID data in query param '%@', length: %d", item.name, (item.value ?? "").count)
                case "error", "errormessage", "errmessage", "errcode":
                    error = item.value
                    NSLog("[IRCTCRailtelSDK] Found error in query param '%@': %@", item.name, item.value ?? "nil")
                default:
                    break
                }
            }
        }
        
        // Method 2: Check full URL string for PID data
        if pidData == nil {
            let urlString = url.absoluteString.removingPercentEncoding ?? url.absoluteString
            NSLog("[IRCTCRailtelSDK] No PID in query params, checking full URL...")
            NSLog("[IRCTCRailtelSDK] Decoded URL (first 500): %@", String(urlString.prefix(500)))
            
            if urlString.contains("<PidData") {
                if let pidStart = urlString.range(of: "<PidData"),
                   let pidEnd = urlString.range(of: "</PidData>") {
                    pidData = String(urlString[pidStart.lowerBound..<pidEnd.upperBound])
                    NSLog("[IRCTCRailtelSDK] Extracted PidData XML, length: %d", (pidData ?? "").count)
                } else {
                    pidData = urlString
                    NSLog("[IRCTCRailtelSDK] PidData start found but no end tag, using full URL")
                }
            } else if urlString.contains("errCode") || urlString.contains("Resp") {
                pidData = urlString
                NSLog("[IRCTCRailtelSDK] URL contains response elements, using as PID data")
            }
        }
        
        // Method 3: Check URL path for base64 encoded response
        if pidData == nil {
            let path = url.path
            if !path.isEmpty && path != "/" {
                NSLog("[IRCTCRailtelSDK] Checking URL path for base64: %@", String(path.prefix(200)))
                let trimmedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                if let decoded = Data(base64Encoded: trimmedPath),
                   let decodedStr = String(data: decoded, encoding: .utf8) {
                    pidData = decodedStr
                    NSLog("[IRCTCRailtelSDK] Decoded base64 PID from path, length: %d", decodedStr.count)
                }
            }
        }
        
        // Method 4: Check if the entire URL after scheme is the response
        if pidData == nil {
            let fullStr = url.absoluteString
            if let schemeEnd = fullStr.range(of: "://") {
                let afterScheme = String(fullStr[schemeEnd.upperBound...])
                let decoded = afterScheme.removingPercentEncoding ?? afterScheme
                NSLog("[IRCTCRailtelSDK] After scheme (first 300): %@", String(decoded.prefix(300)))
                if decoded.contains("<") || decoded.contains("PidData") || decoded.contains("errCode") {
                    pidData = decoded
                    NSLog("[IRCTCRailtelSDK] Using after-scheme content as PID, length: %d", decoded.count)
                }
            }
        }
        
        NSLog("[IRCTCRailtelSDK] ===== PARSING RESULT =====")
        NSLog("[IRCTCRailtelSDK] pidData found: %@, length: %d", pidData != nil ? "YES" : "NO", (pidData ?? "").count)
        NSLog("[IRCTCRailtelSDK] pidData (first 500): %@", String((pidData ?? "nil").prefix(500)))
        NSLog("[IRCTCRailtelSDK] error: %@", error ?? "nil")
        
        if let pid = pidData, !pid.isEmpty {
            if pid.contains("errCode=\"0\"") || pid.contains("errCode=&quot;0&quot;") || pid.contains("PID_CREATED") {
                NSLog("[IRCTCRailtelSDK] SUCCESS - PID captured successfully!")
                result(pid)
            } else {
                // Extract error info
                let errInfoPattern = "errInfo=\"(.+?)\""
                let errCodePattern = "errCode=\"(.+?)\""
                var errMsg = "Face capture failed"
                var errCode = "unknown"
                
                if let regex = try? NSRegularExpression(pattern: errCodePattern),
                   let match = regex.firstMatch(in: pid, range: NSRange(pid.startIndex..., in: pid)),
                   let range = Range(match.range(at: 1), in: pid) {
                    errCode = String(pid[range])
                }
                
                if let regex = try? NSRegularExpression(pattern: errInfoPattern),
                   let match = regex.firstMatch(in: pid, range: NSRange(pid.startIndex..., in: pid)),
                   let range = Range(match.range(at: 1), in: pid) {
                    errMsg = String(pid[range])
                }
                
                NSLog("[IRCTCRailtelSDK] FACE RD ERROR: code=%@, message=%@", errCode, errMsg)
                result(FlutterError(code: "FACE_CAPTURE_ERROR", message: "Error (\(errCode)): \(errMsg)", details: pid))
            }
        } else if let err = error {
            NSLog("[IRCTCRailtelSDK] ERROR from query param: %@", err)
            result(FlutterError(code: "FACE_RD_ERROR", message: err, details: nil))
        } else {
            NSLog("[IRCTCRailtelSDK] NO PID DATA FOUND - treating as cancelled")
            result(FlutterError(code: "CANCELLED", message: "No response from Face RD", details: url.absoluteString))
        }
        
        IRCTCRailtelPlugin.pendingTxnId = nil
        return true
    }
    
    // MARK: - App Lifecycle
    
    public func applicationDidBecomeActive(_ application: UIApplication) {
        NSLog("[IRCTCRailtelSDK] ===== APP BECAME ACTIVE =====")
        NSLog("[IRCTCRailtelSDK] pendingResult exists: %@", IRCTCRailtelPlugin.pendingResult != nil ? "YES" : "NO")
        NSLog("[IRCTCRailtelSDK] pendingTxnId: %@", IRCTCRailtelPlugin.pendingTxnId ?? "nil")
        
        // Check if there's a stored txnId from Face RD (per UIDAI sample)
        let storedTxnId = UserDefaults.standard.string(forKey: "ReceivedTransactionID")
        NSLog("[IRCTCRailtelSDK] Stored txnId in UserDefaults: %@", storedTxnId ?? "nil")
        
        // Check UIPasteboard for any data from Face RD
        let pasteboardStr = UIPasteboard.general.string ?? "nil"
        if pasteboardStr.contains("PidData") || pasteboardStr.contains("errCode") {
            NSLog("[IRCTCRailtelSDK] FOUND PID data in pasteboard! Length: %d", pasteboardStr.count)
            NSLog("[IRCTCRailtelSDK] Pasteboard (first 500): %@", String(pasteboardStr.prefix(500)))
        } else {
            NSLog("[IRCTCRailtelSDK] No PID data in pasteboard")
        }
        
        if IRCTCRailtelPlugin.pendingResult != nil {
            NSLog("[IRCTCRailtelSDK] Waiting 10s for Face RD URL callback...")
            
            // Check at 2s, 5s, and 10s intervals
            for delay in [2.0, 5.0, 10.0] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    if IRCTCRailtelPlugin.pendingResult != nil {
                        NSLog("[IRCTCRailtelSDK] Still waiting at %.0fs... pendingResult exists: YES", delay)
                        
                        if delay >= 10.0 {
                            if let result = IRCTCRailtelPlugin.pendingResult {
                                NSLog("[IRCTCRailtelSDK] ===== TIMEOUT - NO CALLBACK AFTER 10s =====")
                                NSLog("[IRCTCRailtelSDK] Face RD did NOT call back via URL scheme")
                                NSLog("[IRCTCRailtelSDK] Possible causes:")
                                NSLog("[IRCTCRailtelSDK]   1. Face RD errored (e.g. 739 timeout) and doesn't send callback on error")
                                NSLog("[IRCTCRailtelSDK]   2. Face RD doesn't know our URL scheme")
                                NSLog("[IRCTCRailtelSDK]   3. UIDAI server processing timed out inside Face RD")
                                
                                // Final pasteboard check
                                let finalPaste = UIPasteboard.general.string ?? ""
                                if finalPaste.contains("PidData") || finalPaste.contains("errCode") {
                                    NSLog("[IRCTCRailtelSDK] PID data appeared in pasteboard! Returning it.")
                                    IRCTCRailtelPlugin.pendingResult = nil
                                    IRCTCRailtelPlugin.pendingTxnId = nil
                                    result(finalPaste)
                                    return
                                }
                                
                                IRCTCRailtelPlugin.pendingResult = nil
                                IRCTCRailtelPlugin.pendingTxnId = nil
                                result(FlutterError(
                                    code: "FACE_RD_TIMEOUT",
                                    message: "Face RD did not return a response. The Face RD app may have encountered a server error (e.g. timeout 739). Please check internet connectivity and try again.",
                                    details: nil
                                ))
                            }
                        }
                    } else {
                        NSLog("[IRCTCRailtelSDK] At %.0fs: pendingResult is nil (callback already received or handled)", delay)
                    }
                }
            }
        }
    }
}
