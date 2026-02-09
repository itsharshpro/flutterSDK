import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'models.dart';
import 'irctc_railtel_sdk.dart';
import 'face_rd_service.dart';

/// Main verification screen that handles the entire flow
/// Matches Android SDK flow: Aadhaar Entry → Method Selection → Verification → Result
class VerificationScreen extends StatefulWidget {
  final String? aadhaarNumber;
  
  const VerificationScreen({super.key, this.aadhaarNumber});
  
  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  _Step _currentStep = _Step.aadhaarEntry;
  String? _aadhaarNumber;
  String? _reqId;
  String? _maskedMobile;
  String? _transactionId;
  bool _isLoading = false;
  String? _error;
  VerificationMethod? _verificationMethod;
  
  // Controllers
  final _aadhaar1 = TextEditingController();
  final _aadhaar2 = TextEditingController();
  final _aadhaar3 = TextEditingController();
  final List<TextEditingController> _otpControllers = 
      List.generate(6, (_) => TextEditingController());
  
  // Focus nodes for auto-jump
  final _focus1 = FocusNode();
  final _focus2 = FocusNode();
  final _focus3 = FocusNode();
  
  @override
  void initState() {
    super.initState();
    if (widget.aadhaarNumber != null && widget.aadhaarNumber!.length == 12) {
      _aadhaarNumber = widget.aadhaarNumber;
      _aadhaar1.text = widget.aadhaarNumber!.substring(0, 4);
      _aadhaar2.text = widget.aadhaarNumber!.substring(4, 8);
      _aadhaar3.text = widget.aadhaarNumber!.substring(8, 12);
      // Skip to method selection if Aadhaar provided
      _goToMethodSelectionOrFaceAuth();
    }
  }
  
  void _goToMethodSelectionOrFaceAuth() {
    final config = IRCTCRailtelSDK.config;
    if (config.enableOtp) {
      setState(() => _currentStep = _Step.methodSelection);
    } else {
      // Skip directly to Face Auth if OTP not enabled
      _selectFaceRD();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _handleBack();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(_getTitle()),
          backgroundColor: const Color(0xFF1976D2),
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
        ),
        body: _buildBody(),
      ),
    );
  }
  
  String _getTitle() {
    switch (_currentStep) {
      case _Step.aadhaarEntry:
        return 'Enter Aadhaar Number';
      case _Step.methodSelection:
        return 'Choose Verification Method';
      case _Step.faceAuth:
        return 'Face Authentication';
      case _Step.otpVerification:
        return 'OTP Verification';
      case _Step.result:
        return 'Verification Result';
    }
  }
  
  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingScreen();
    }
    
    switch (_currentStep) {
      case _Step.aadhaarEntry:
        return _buildAadhaarEntry();
      case _Step.methodSelection:
        return _buildMethodSelection();
      case _Step.faceAuth:
        return _buildFaceAuth();
      case _Step.otpVerification:
        return _buildOtpVerification();
      case _Step.result:
        return _buildResult();
    }
  }
  
  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1976D2)),
          ),
          const SizedBox(height: 24),
          Text(
            _currentStep == _Step.faceAuth 
                ? 'Processing Face Authentication...' 
                : 'Please wait...',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
  
  // ==================== AADHAAR ENTRY SCREEN ====================
  Widget _buildAadhaarEntry() {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1976D2).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: const Icon(
                    Icons.credit_card,
                    size: 48,
                    color: Color(0xFF1976D2),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Enter your 12-digit Aadhaar Number',
                  style: TextStyle(fontSize: 16, color: Color(0xFF333333)),
                ),
                const SizedBox(height: 24),
                
                // Aadhaar Input Fields
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildAadhaarField(_aadhaar1, _focus1, _focus2, null),
                    const Text(' - ', style: TextStyle(fontSize: 24, color: Color(0xFF666666))),
                    _buildAadhaarField(_aadhaar2, _focus2, _focus3, _focus1),
                    const Text(' - ', style: TextStyle(fontSize: 24, color: Color(0xFF666666))),
                    _buildAadhaarField(_aadhaar3, _focus3, null, _focus2),
                  ],
                ),
                
                // Error message
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 14)),
                ],
              ],
            ),
          ),
        ),
        
        // Buttons
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _proceedFromAadhaar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Proceed', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(VerificationResult.cancelled()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF757575),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildAadhaarField(
    TextEditingController controller,
    FocusNode focusNode,
    FocusNode? nextFocus,
    FocusNode? previousFocus,
  ) {
    return SizedBox(
      width: 80,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        maxLength: 4,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          counterText: '',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFBDBDBD)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
        onChanged: (value) {
          if (value.length == 4 && nextFocus != null) {
            nextFocus.requestFocus();
          }
          if (value.isEmpty && previousFocus != null) {
            previousFocus.requestFocus();
          }
          setState(() => _error = null);
        },
      ),
    );
  }
  
  // ==================== METHOD SELECTION SCREEN ====================
  Widget _buildMethodSelection() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          const Text(
            'How would you like to verify your identity?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Color(0xFF333333)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Select a verification method',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 40),
          
          // OTP Option
          _buildMethodCard(
            icon: Icons.sms_outlined,
            title: 'OTP Verification',
            subtitle: 'Receive OTP on Aadhaar-linked mobile number',
            onTap: _selectOtp,
          ),
          const SizedBox(height: 16),
          
          // Face RD Option
          _buildMethodCard(
            icon: Icons.face_outlined,
            title: 'Face Authentication',
            subtitle: 'Verify using Face RD biometric recognition',
            onTap: _selectFaceRD,
          ),
          
          const Spacer(),
          
          // Cancel button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(VerificationResult.cancelled()),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF757575)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Cancel', style: TextStyle(fontSize: 16, color: Color(0xFF757575))),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMethodCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1976D2).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 32, color: const Color(0xFF1976D2)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
  
  // ==================== FACE AUTH SCREEN ====================
  Widget _buildFaceAuth() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1976D2).withOpacity(0.1),
              borderRadius: BorderRadius.circular(100),
            ),
            child: const Icon(
              Icons.face,
              size: 80,
              color: Color(0xFF1976D2),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Face Authentication',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'Position your face within the frame and follow the on-screen instructions',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.5),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _startFaceCapture,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Start Face Capture', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  // ==================== OTP VERIFICATION SCREEN ====================
  Widget _buildOtpVerification() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1976D2).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: const Icon(
                    Icons.sms_outlined,
                    size: 48,
                    color: Color(0xFF1976D2),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Enter OTP sent to',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  _maskedMobile ?? 'Aadhaar registered mobile',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1976D2),
                  ),
                ),
                const SizedBox(height: 32),
                
                // OTP Input Fields
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(6, (i) => SizedBox(
                    width: 45,
                    child: TextField(
                      controller: _otpControllers[i],
                      maxLength: 1,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
                        ),
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty && i < 5) {
                          FocusScope.of(context).nextFocus();
                        }
                        setState(() => _error = null);
                      },
                    ),
                  )),
                ),
                
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                
                const SizedBox(height: 24),
                TextButton(
                  onPressed: _sendOtp,
                  child: const Text('Resend OTP', style: TextStyle(color: Color(0xFF1976D2))),
                ),
              ],
            ),
          ),
          
          // Verify Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _verifyOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Verify OTP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
  
  // ==================== RESULT SCREEN ====================
  Widget _buildResult() {
    final isSuccess = _error == null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Success/Failure Icon
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: (isSuccess ? Colors.green : Colors.red).withOpacity(0.1),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Icon(
                isSuccess ? Icons.check_circle : Icons.cancel,
                size: 80,
                color: isSuccess ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              isSuccess ? 'Verification Successful' : 'Verification Failed',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              isSuccess 
                  ? 'Your identity has been verified successfully.'
                  : _error ?? 'Verification could not be completed.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, height: 1.5),
            ),
            
            // Transaction ID
            if (isSuccess && _transactionId != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Text('Transaction ID:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    SelectableText(
                      _transactionId!,
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
            
            // Method info
            if (isSuccess && _verificationMethod != null) ...[
              const SizedBox(height: 16),
              Chip(
                label: Text(
                  'Verified via ${_verificationMethod == VerificationMethod.otp ? 'OTP' : 'Face RD'}',
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: const Color(0xFF1976D2),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  // ==================== NAVIGATION ====================
  void _handleBack() {
    switch (_currentStep) {
      case _Step.aadhaarEntry:
        Navigator.of(context).pop(VerificationResult.cancelled());
        break;
      case _Step.methodSelection:
        setState(() => _currentStep = _Step.aadhaarEntry);
        break;
      case _Step.faceAuth:
      case _Step.otpVerification:
        final config = IRCTCRailtelSDK.config;
        if (config.enableOtp) {
          setState(() => _currentStep = _Step.methodSelection);
        } else {
          setState(() => _currentStep = _Step.aadhaarEntry);
        }
        break;
      case _Step.result:
        Navigator.of(context).pop(VerificationResult.cancelled());
        break;
    }
  }
  
  void _proceedFromAadhaar() {
    final aadhaar = _aadhaar1.text + _aadhaar2.text + _aadhaar3.text;
    if (aadhaar.length != 12 || !RegExp(r'^\d{12}$').hasMatch(aadhaar)) {
      setState(() => _error = 'Please enter a valid 12-digit Aadhaar number');
      return;
    }
    if (aadhaar[0] == '0' || aadhaar[0] == '1') {
      setState(() => _error = 'Aadhaar cannot start with 0 or 1');
      return;
    }
    _aadhaarNumber = aadhaar;
    _goToMethodSelectionOrFaceAuth();
  }
  
  void _selectOtp() {
    _verificationMethod = VerificationMethod.otp;
    setState(() => _currentStep = _Step.otpVerification);
    _sendOtp();
  }
  
  void _selectFaceRD() {
    _verificationMethod = VerificationMethod.faceRD;
    setState(() => _currentStep = _Step.faceAuth);
  }
  
  // ==================== FACE RD CAPTURE ====================
  Future<void> _startFaceCapture() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      // Check if Face RD is available
      final isAvailable = await FaceRDService.isFaceRDAvailable();
      if (!isAvailable) {
        throw Exception('Face RD app not installed. Please install AadhaarFaceRD from ${Platform.isIOS ? 'App Store' : 'Play Store'}.');
      }
      
      // Capture face using Face RD app with KYC enabled
      final pidData = await FaceRDService.capture(
        isDemo: !IRCTCRailtelSDK.config.isProduction,
        enableKyc: true,
      );
      
      // Verify with API
      await _verifyFaceWithAPI(pidData);
      
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }
  
  Future<void> _verifyFaceWithAPI(String pidData) async {
    try {
      final response = await http.post(
        Uri.parse('${SDKConfig.apiBaseUrl}/uidauth'),
        headers: {
          'Content-Type': 'application/json',
          'token': SDKConfig.apiToken,
        },
        body: jsonEncode({
          'bio': pidData,
          'uid': _aadhaarNumber,
          'phone': '9999999999',
          'kyc': true,
        }),
      ).timeout(const Duration(seconds: 30));
      
      final json = jsonDecode(response.body);
      final failed = json['failed'] ?? true;
      
      _transactionId = json['reqid'] ?? json['requestId'];
      
      if (!failed) {
        setState(() {
          _currentStep = _Step.result;
          _error = null;
          _isLoading = false;
        });
        
        // Auto-return after 3 seconds
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) {
          Navigator.of(context).pop(VerificationResult.success(
            method: VerificationMethod.faceRD,
            aadhaarNumber: _aadhaarNumber,
            transactionId: _transactionId,
          ));
        }
      } else {
        final errorMsg = json['message'] ?? json['errMsg'] ?? 'Face verification failed';
        throw Exception(errorMsg);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      rethrow;
    }
  }
  
  // ==================== OTP VERIFICATION ====================
  Future<void> _sendOtp() async {
    setState(() => _isLoading = true);
    
    try {
      final response = await http.post(
        Uri.parse('${SDKConfig.apiBaseUrl}/otpuidauth?kyc=true'),
        headers: {
          'Content-Type': 'application/json',
          'token': SDKConfig.apiToken,
        },
        body: jsonEncode({
          'phone': '9999999999',
          'uid': _aadhaarNumber,
          'device_id': 'flutter_device',
          'model': Platform.isIOS ? 'iOS' : 'Android',
          'mode': 'sendOtp',
          'kyc': true,
          'otp': '',
          'reqid': '',
        }),
      );
      
      final json = jsonDecode(response.body);
      _reqId = json['reqid'] ?? json['requestId'] ?? json['txn'];
      _maskedMobile = json['maskedMobile'] ?? json['mobile'];
      
      if (_reqId == null) {
        _error = json['message'] ?? json['errMsg'] ?? 'Failed to send OTP';
      }
    } catch (e) {
      _error = 'Network error: ${e.toString()}';
    }
    
    setState(() => _isLoading = false);
  }
  
  Future<void> _verifyOtp() async {
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length != 6) {
      setState(() => _error = 'Please enter complete 6-digit OTP');
      return;
    }
    
    if (_reqId == null) {
      setState(() => _error = 'Session expired. Please resend OTP.');
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final response = await http.post(
        Uri.parse('${SDKConfig.apiBaseUrl}/otpuidauth?kyc=true'),
        headers: {
          'Content-Type': 'application/json',
          'token': SDKConfig.apiToken,
        },
        body: jsonEncode({
          'phone': '9999999999',
          'uid': _aadhaarNumber,
          'device_id': 'flutter_device',
          'model': Platform.isIOS ? 'iOS' : 'Android',
          'mode': 'verifyOtp',
          'kyc': true,
          'otp': otp,
          'reqid': _reqId,
        }),
      );
      
      final json = jsonDecode(response.body);
      final failed = json['failed'] ?? false;
      final status = json['status']?.toString().toLowerCase();
      
      _transactionId = json['reqid'] ?? json['requestId'] ?? _reqId;
      
      if (!failed || status == 'success') {
        setState(() {
          _currentStep = _Step.result;
          _error = null;
        });
        
        // Auto-return after 3 seconds
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) {
          Navigator.of(context).pop(VerificationResult.success(
            method: VerificationMethod.otp,
            aadhaarNumber: _aadhaarNumber,
            transactionId: _transactionId,
            name: json['poi']?['name'] ?? json['kyc']?['name'] ?? json['name'],
            dob: json['poi']?['dob'] ?? json['kyc']?['dob'] ?? json['dob'],
            photo: json['poi']?['photo'] ?? json['kyc']?['photo'] ?? json['photo'],
          ));
        }
      } else {
        _error = json['message'] ?? json['errMsg'] ?? 'Verification failed';
        for (var c in _otpControllers) {
          c.clear();
        }
      }
    } catch (e) {
      _error = 'Network error: ${e.toString()}';
    }
    
    setState(() => _isLoading = false);
  }
  
  @override
  void dispose() {
    _aadhaar1.dispose();
    _aadhaar2.dispose();
    _aadhaar3.dispose();
    _focus1.dispose();
    _focus2.dispose();
    _focus3.dispose();
    for (var c in _otpControllers) {
      c.dispose();
    }
    super.dispose();
  }
}

enum _Step {
  aadhaarEntry,
  methodSelection,
  faceAuth,
  otpVerification,
  result,
}
