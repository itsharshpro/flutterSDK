import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'models.dart';
import 'irctc_railtel_sdk.dart';
import 'face_rd_service.dart';

/// Main verification screen that handles the entire flow
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
  
  // Controllers
  final _aadhaar1 = TextEditingController();
  final _aadhaar2 = TextEditingController();
  final _aadhaar3 = TextEditingController();
  final List<TextEditingController> _otpControllers = 
      List.generate(6, (_) => TextEditingController());
  
  @override
  void initState() {
    super.initState();
    if (widget.aadhaarNumber != null && widget.aadhaarNumber!.length == 12) {
      _aadhaarNumber = widget.aadhaarNumber;
      _currentStep = _Step.methodSelection;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle()),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _handleBack,
        ),
      ),
      body: _buildBody(),
    );
  }
  
  String _getTitle() {
    switch (_currentStep) {
      case _Step.aadhaarEntry:
        return 'Enter Aadhaar Number';
      case _Step.methodSelection:
        return 'Choose Verification Method';
      case _Step.otpVerification:
        return 'OTP Verification';
      case _Step.result:
        return 'Verification Result';
    }
  }
  
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    switch (_currentStep) {
      case _Step.aadhaarEntry:
        return _buildAadhaarEntry();
      case _Step.methodSelection:
        return _buildMethodSelection();
      case _Step.otpVerification:
        return _buildOtpVerification();
      case _Step.result:
        return _buildResult();
    }
  }
  
  Widget _buildAadhaarEntry() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Enter your 12-digit Aadhaar Number',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildAadhaarField(_aadhaar1, _aadhaar2),
              const Text(' - ', style: TextStyle(fontSize: 24)),
              _buildAadhaarField(_aadhaar2, _aadhaar3, _aadhaar1),
              const Text(' - ', style: TextStyle(fontSize: 24)),
              _buildAadhaarField(_aadhaar3, null, _aadhaar2),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _proceedFromAadhaar,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
              minimumSize: const Size(200, 50),
            ),
            child: const Text('Proceed'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAadhaarField(
    TextEditingController controller,
    TextEditingController? next, [
    TextEditingController? previous,
  ]) {
    return SizedBox(
      width: 80,
      child: TextField(
        controller: controller,
        maxLength: 4,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        decoration: const InputDecoration(
          counterText: '',
          border: OutlineInputBorder(),
        ),
        onChanged: (value) {
          if (value.length == 4 && next != null) {
            FocusScope.of(context).nextFocus();
          }
          setState(() => _error = null);
        },
      ),
    );
  }
  
  Widget _buildMethodSelection() {
    final config = IRCTCRailtelSDK.config;
    
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Select a verification method', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 32),
          
          // Show OTP option only if enabled in config
          if (config.enableOtp) ...[
            _buildMethodCard(
              icon: Icons.sms,
              title: 'OTP Verification',
              subtitle: 'Receive OTP on Aadhaar-linked mobile',
              onTap: _selectOtp,
            ),
            const SizedBox(height: 16),
          ],
          
          // Face RD is always available
          _buildMethodCard(
            icon: Icons.face,
            title: 'Face Authentication',
            subtitle: 'Verify using Face RD biometrics',
            onTap: _selectFaceRD,
            enabled: true,
          ),
        ],
      ),
    );
  }
  
  Widget _buildMethodCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    bool enabled = true,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 40, color: enabled ? const Color(0xFF1976D2) : Colors.grey),
        title: Text(title, style: TextStyle(color: enabled ? null : Colors.grey)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: enabled ? onTap : null,
        enabled: enabled,
      ),
    );
  }
  
  Widget _buildOtpVerification() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Enter OTP sent to', style: TextStyle(fontSize: 16)),
          Text(
            _maskedMobile ?? 'Aadhaar registered mobile',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1976D2),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(6, (i) => SizedBox(
              width: 45,
              child: TextField(
                controller: _otpControllers[i],
                maxLength: 1,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  counterText: '',
                  border: OutlineInputBorder(),
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
            child: const Text('Resend OTP'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _verifyOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
              minimumSize: const Size(200, 50),
            ),
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildResult() {
    final isSuccess = _error == null;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSuccess ? Icons.check_circle : Icons.cancel,
            size: 100,
            color: isSuccess ? Colors.green : Colors.red,
          ),
          const SizedBox(height: 24),
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
            style: const TextStyle(color: Colors.grey),
          ),
          if (isSuccess && _transactionId != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  const Text('Transaction ID:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(
                    _transactionId!,
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  void _handleBack() {
    if (_currentStep == _Step.aadhaarEntry) {
      Navigator.of(context).pop(VerificationResult.cancelled());
    } else if (_currentStep == _Step.methodSelection) {
      if (widget.aadhaarNumber != null) {
        Navigator.of(context).pop(VerificationResult.cancelled());
      } else {
        setState(() => _currentStep = _Step.aadhaarEntry);
      }
    } else if (_currentStep == _Step.otpVerification) {
      setState(() => _currentStep = _Step.methodSelection);
    } else {
      Navigator.of(context).pop(VerificationResult.cancelled());
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
    setState(() => _currentStep = _Step.methodSelection);
  }
  
  void _selectOtp() {
    setState(() => _currentStep = _Step.otpVerification);
    _sendOtp();
  }
  
  Future<void> _selectFaceRD() async {
    setState(() => _isLoading = true);
    
    try {
      // Capture face using Face RD app with KYC enabled
      final pidData = await FaceRDService.capture(
        isDemo: !IRCTCRailtelSDK.config.isProduction,
        enableKyc: true, // Always use KYC for UKC transaction ID
      );
      
      // Verify with API
      await _verifyFaceWithAPI(pidData);
      
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Face capture failed: $_error')),
        );
      }
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
          'kyc': true, // Always true for UKC transaction ID
        }),
      ).timeout(const Duration(seconds: 30));
      
      final json = jsonDecode(response.body);
      final failed = json['failed'] ?? true;
      
      // Parse transaction ID from response
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
  
  Future<void> _sendOtp() async {
    setState(() => _isLoading = true);
    
    try {
      // OTP endpoint with kyc=true query param
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
          'kyc': true, // Always true for UKC transaction ID
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
      setState(() => _error = 'Please enter complete OTP');
      return;
    }
    
    if (_reqId == null) {
      setState(() => _error = 'Session expired. Please resend OTP.');
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      // Verify OTP with kyc=true
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
          'kyc': true, // Always true for UKC transaction ID
          'otp': otp,
          'reqid': _reqId,
        }),
      );
      
      final json = jsonDecode(response.body);
      final failed = json['failed'] ?? false;
      final status = json['status']?.toString().toLowerCase();
      
      // Parse transaction ID from response (should have UKC prefix)
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
    for (var c in _otpControllers) {
      c.dispose();
    }
    super.dispose();
  }
}

enum _Step {
  aadhaarEntry,
  methodSelection,
  otpVerification,
  result,
}
