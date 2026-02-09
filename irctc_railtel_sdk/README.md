# IRCTCRailtel Flutter SDK

A Flutter plugin for Aadhaar-based identity verification using UIDAI-certified biometric services.

## Features

- **Face RD Authentication** - Face biometric verification using UIDAI-certified Face RD apps
- **OTP Authentication** - Mobile OTP-based Aadhaar verification (optional)
- **Cross-platform** - Works on Android and iOS
- **Pure Dart** - No native code integration required

## Requirements

| Platform | Requirement |
|----------|-------------|
| Android | API 24+ (Android 7.0) |
| iOS | iOS 14+ |
| Flutter | 3.0.0+ |
| Face RD | AadhaarFaceRD app installed |

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  irctc_railtel_sdk:
    path: ../irctc_railtel_sdk  # or your path to the SDK
```

## Quick Start

### 1. Initialize the SDK

```dart
import 'package:irctc_railtel_sdk/irctc_railtel_sdk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await IRCTCRailtelSDK.initialize(
    config: SDKConfig(
      environment: Environment.production,
      enableOtp: true,   // Show OTP option
      enableKyc: false,  // Get user details
    ),
  );
  
  runApp(MyApp());
}
```

### 2. Start Verification

```dart
final result = await IRCTCRailtelSDK.startVerification(context);

if (result.isSuccess) {
  print('Verified via: ${result.data?.method}');
  print('Transaction ID: ${result.data?.transactionId}');
} else if (result.isCancelled) {
  print('User cancelled');
} else {
  print('Error: ${result.errorMessage}');
}
```

## Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `environment` | `Environment` | `production` | `production` or `demo` |
| `enableOtp` | `bool` | `false` | Enable OTP verification option |
| `enableKyc` | `bool` | `false` | Return name, DOB, photo in result |

## Verification Result

```dart
class VerificationResult {
  bool isSuccess;
  bool isCancelled;
  String? errorCode;
  String? errorMessage;
  VerificationData? data;
}

class VerificationData {
  VerificationMethod method;     // otp or faceRD
  String? aadhaarNumber;
  String? transactionId;         // UKC:xxxx format
  String? name;                  // if KYC enabled
  String? dob;                   // if KYC enabled
  String? photo;                 // Base64, if KYC enabled
}
```

## Transaction ID Format

The `transactionId` is returned with a `UKC:` prefix:

| Format | Method |
|--------|--------|
| `UKC:OTP:0003900000:...` | OTP verification |
| `UKC:0003900000:...` | Face RD verification |

## Face RD Requirements

### Android
Install **AadhaarFaceRD** from Google Play Store.

### iOS
Install **AadhaarFaceRD** from Apple App Store.

## Verification Flow

```
┌─────────────────┐
│  Aadhaar Entry  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Method Selection│  (if enableOtp=true)
│  Face RD / OTP  │
└────────┬────────┘
         │
    ┌────┴────┐
    ▼         ▼
┌───────┐ ┌──────┐
│Face RD│ │ OTP  │
│Capture│ │Verify│
└───┬───┘ └──┬───┘
    │        │
    └────┬───┘
         ▼
┌─────────────────┐
│  Result Screen  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Callback Result │
└─────────────────┘
```

## Error Codes

| Code | Description |
|------|-------------|
| `NOT_INITIALIZED` | SDK not initialized |
| `NO_FACE_RD` | Face RD app not installed |
| `CANCELLED` | User cancelled |
| `CAPTURE_FAILED` | Face capture failed |
| `NETWORK_ERROR` | Network issue |
| `SERVER_ERROR` | API error |

## Sample App

See `sample_app/` for a complete integration example:

```bash
cd sample_app
flutter pub get
flutter run
```

## License

Proprietary - IRCTC Railtel
