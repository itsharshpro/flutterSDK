/// SDK Configuration
class SDKConfig {
  final Environment environment;
  final bool enableKyc;
  final bool enableOtp;
  
  // API endpoints - matching Android SDK
  static const String apiBaseUrl = 'https://examify.co.in/api/exa/seqr';
  static const String demoAuthUrl = 'https://examify.co.in/api/demoauth';
  
  // API tokens
  static const String apiToken = '7alckyg32jzlmb2i2rwf4itdhna2bzb2';
  static const String demoAuthToken = 'f7aa24903a5e4ce59dc5c7e87dd5be4e';
  
  SDKConfig({
    this.environment = Environment.production,
    this.enableKyc = false,
    this.enableOtp = false,
  });
  
  bool get isProduction => environment == Environment.production;
  String get envCode => environment == Environment.production ? 'P' : 'PP';
}

enum Environment {
  production,
  demo,
}

/// Verification Result
class VerificationResult {
  final VerificationStatus status;
  final String? errorCode;
  final String? errorMessage;
  final VerificationData? data;
  
  VerificationResult._({
    required this.status,
    this.errorCode,
    this.errorMessage,
    this.data,
  });
  
  factory VerificationResult.success({
    required VerificationMethod method,
    String? aadhaarNumber,
    String? transactionId,
    String? name,
    String? dob,
    String? photo,
  }) {
    return VerificationResult._(
      status: VerificationStatus.success,
      data: VerificationData(
        verified: true,
        method: method,
        aadhaarNumber: aadhaarNumber,
        transactionId: transactionId,
        name: name,
        dob: dob,
        photo: photo,
      ),
    );
  }
  
  factory VerificationResult.failure({
    required String errorCode,
    required String message,
  }) {
    return VerificationResult._(
      status: VerificationStatus.failure,
      errorCode: errorCode,
      errorMessage: message,
    );
  }
  
  factory VerificationResult.cancelled() {
    return VerificationResult._(
      status: VerificationStatus.cancelled,
    );
  }
  
  bool get isSuccess => status == VerificationStatus.success;
  bool get isCancelled => status == VerificationStatus.cancelled;
}

enum VerificationStatus {
  success,
  failure,
  cancelled,
}

/// Verification Data
class VerificationData {
  final bool verified;
  final VerificationMethod method;
  final String? aadhaarNumber;
  final String? transactionId;
  final String? name;
  final String? dob;
  final String? photo;
  
  VerificationData({
    required this.verified,
    required this.method,
    this.aadhaarNumber,
    this.transactionId,
    this.name,
    this.dob,
    this.photo,
  });
}

enum VerificationMethod {
  otp,
  faceRD,
}
