# Flutter SDK Setup & Testing Guide

This guide covers how to set up Flutter on your machine and run the IRCTCRailtel SDK sample app on Android and iOS.

---

## Prerequisites

### 1. Install Flutter

```bash
# Download Flutter SDK
cd ~/Downloads
curl -O https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_arm64_3.24.0-stable.zip

# Extract to a permanent location
unzip flutter_macos_arm64_3.24.0-stable.zip
sudo mv flutter /opt/flutter

# Add to PATH (add to ~/.zshrc for permanent)
export PATH="$PATH:/opt/flutter/bin"

# Verify installation
flutter doctor
```

**Alternative: Using Homebrew**
```bash
brew install --cask flutter
flutter doctor
```

### 2. Accept Android Licenses

```bash
flutter doctor --android-licenses
```

### 3. Install CocoaPods (for iOS)

```bash
sudo gem install cocoapods
```

---

## Project Setup

### 1. Navigate to Sample App

```bash
cd /Users/harshgupta/Downloads/Projects/inno/irctc_ui/IRCTCRailtelSDK/flutter/sample_app
```

### 2. Get Dependencies

```bash
flutter pub get
```

### 3. Check Flutter Doctor

```bash
flutter doctor
```

Ensure you see ✅ for:
- Flutter
- Android toolchain  
- Xcode (for iOS)
- Android Studio or VS Code

---

## Running on Android

### 1. Connect Android Device

- Enable **Developer Options** on your Android device
- Enable **USB Debugging**
- Connect via USB cable
- Accept the debugging prompt on the device

### 2. Verify Device Connection

```bash
flutter devices
```

You should see your Android device listed.

### 3. Run the App

```bash
cd /Users/harshgupta/Downloads/Projects/inno/irctc_ui/IRCTCRailtelSDK/flutter/sample_app
flutter run
```

### 4. Build APK (Optional)

```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release
```

APK location: `build/app/outputs/flutter-apk/app-debug.apk`

### 5. Install Face RD App

For Face RD authentication to work, install **AadhaarFaceRD** from Play Store on the test device.

---

## Running on iOS

### 1. Open iOS Project in Xcode

```bash
cd /Users/harshgupta/Downloads/Projects/inno/irctc_ui/IRCTCRailtelSDK/flutter/sample_app/ios
open Runner.xcworkspace
```

### 2. Configure Signing

In Xcode:
1. Select **Runner** in the project navigator
2. Go to **Signing & Capabilities** tab
3. Select your **Team** (Apple Developer account)
4. Change **Bundle Identifier** to something unique (e.g., `com.yourcompany.irctcrtlsample`)

### 3. Add URL Scheme for Face RD Callback

In Xcode, go to **Info** tab and add a URL Type:
- **Identifier**: `FaceRDCallback`
- **URL Schemes**: `irctcrailtel` (or your app's custom scheme)

### 4. Connect iOS Device

- Connect iPhone/iPad via USB
- Trust the computer on the device

### 5. Run from Xcode or Terminal

**From Terminal:**
```bash
cd /Users/harshgupta/Downloads/Projects/inno/irctc_ui/IRCTCRailtelSDK/flutter/sample_app
flutter run
```

**From Xcode:**
1. Select your device in the device dropdown
2. Click **Run** (▶️)

### 6. Install Face RD App

For Face RD authentication to work, install **AadhaarFaceRD** from App Store on the test device.

---

## SDK Configuration Options

```dart
SDKConfig config = SDKConfig(
  environment: Environment.production, // or Environment.demo
  enableOtp: true,    // Show OTP option (true/false)
  enableKyc: false,   // Get name, DOB, photo in result
);
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `environment` | `Environment` | `production` | `production` or `demo` |
| `enableOtp` | `bool` | `false` | Show OTP verification option |
| `enableKyc` | `bool` | `false` | Return user details (name, DOB, photo) |

---

## Verification Result

```dart
final result = await IRCTCRailtelSDK.startVerification(context);

if (result.isSuccess) {
  print('Method: ${result.data?.method}');        // otp or faceRD
  print('Aadhaar: ${result.data?.aadhaarNumber}');
  print('Transaction ID: ${result.data?.transactionId}');  // UKC:xxxx
  
  // If KYC enabled:
  print('Name: ${result.data?.name}');
  print('DOB: ${result.data?.dob}');
  print('Photo: ${result.data?.photo}');  // Base64
}
```

---

## Troubleshooting

### Flutter not found
```bash
export PATH="$PATH:/opt/flutter/bin"
```

### Android device not detected
```bash
# Check ADB
adb devices

# Restart ADB
adb kill-server && adb start-server
```

### iOS build fails
```bash
cd ios
pod deintegrate
pod install --repo-update
cd ..
flutter clean
flutter pub get
flutter run
```

### Face RD app not launching
- Ensure AadhaarFaceRD is installed from Play Store/App Store
- Check that the device has internet connectivity
- Verify the app is UIDAI-certified

### OTP not received
- Ensure Aadhaar has a linked mobile number
- Check network connectivity

---

## File Structure

```
IRCTCRailtelSDK/flutter/
├── irctc_railtel_sdk/          # SDK Package
│   ├── lib/
│   │   ├── irctc_railtel_sdk.dart   # Main export
│   │   └── src/
│   │       ├── models.dart          # SDKConfig, VerificationResult
│   │       ├── irctc_railtel_sdk.dart
│   │       ├── verification_screen.dart
│   │       ├── face_rd_service.dart
│   │       └── face_auth_handler.dart
│   └── pubspec.yaml
├── sample_app/                 # Sample App
│   ├── lib/
│   │   └── main.dart
│   ├── android/               # Android project (auto-generated)
│   ├── ios/                   # iOS project (auto-generated)
│   └── pubspec.yaml
└── SETUP.md                   # This file
```

---

## Quick Commands Reference

```bash
# Navigate to sample app
cd /Users/harshgupta/Downloads/Projects/inno/irctc_ui/IRCTCRailtelSDK/flutter/sample_app

# Get dependencies
flutter pub get

# List connected devices
flutter devices

# Run on connected device
flutter run

# Run on specific device
flutter run -d <device_id>

# Build debug APK
flutter build apk --debug

# Build release APK
flutter build apk --release

# Clean project
flutter clean

# Check for issues
flutter doctor -v
```
