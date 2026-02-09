import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

/// Face Authentication Handler for Flutter
/// Note: Face RD Service is Android-specific and requires native integration.
/// This handler provides the API integration for face auth verification.
class FaceAuthHandler {
  
  /// Verify face biometric data with TrustView API
  /// 
  /// Returns true if verification was successful, throws exception otherwise.
  static Future<bool> verifyFace({
    required String aadhaarNumber,
    required String pidData,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${SDKConfig.apiBaseUrl}/uidauth'),
        headers: {
          'Content-Type': 'application/json',
          'token': SDKConfig.apiToken,
        },
        body: jsonEncode({
          'bio': pidData,
          'uid': aadhaarNumber,
          'phone': '9999999999',  // Required by TrustView API
          'kyc': false,
        }),
      ).timeout(const Duration(seconds: 30));
      
      final json = jsonDecode(response.body);
      
      // TrustView uses "failed": false for success
      final failed = json['failed'] ?? true;
      
      if (!failed) {
        return true;
      } else {
        final errorMsg = json['message'] ?? json['errMsg'] ?? 'Face verification failed';
        throw Exception(errorMsg);
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Network error: ${e.toString()}');
    }
  }
}
