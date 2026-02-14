import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'models.dart';
import 'irctc_railtel_sdk.dart';
import 'face_rd_service.dart';

/// Main verification screen that handles the entire flow
/// Matches Android SDK flow: Aadhaar Entry → Demographics Entry → Demographics Verify → Method Selection → Verification → Result
class VerificationScreen extends StatefulWidget {
  final String? aadhaarNumber;
  final String? name;
  final String? dob;
  final String? gender;
  
  const VerificationScreen({
    super.key, 
    this.aadhaarNumber,
    this.name,
    this.dob,
    this.gender,
  });
  
  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  _Step _currentStep = _Step.aadhaarEntry;
  String? _aadhaarNumber;
  String? _demographicsName;
  String? _demographicsDob;
  String? _demographicsGender;
  String? _demographicsToken;
  String? _reqId;
  String? _maskedMobile;
  String? _transactionId;
  bool _isLoading = false;
  String? _error;
  VerificationMethod? _verificationMethod;
  bool? _isFaceRDAvailable;
  
  // Controllers - Aadhaar
  final _aadhaar1 = TextEditingController();
  final _aadhaar2 = TextEditingController();
  final _aadhaar3 = TextEditingController();
  
  // Controllers - Demographics
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  String _selectedGender = 'M'; // Default Male
  
  // Controllers - OTP
  final List<TextEditingController> _otpControllers = 
      List.generate(6, (_) => TextEditingController());
  
  // Focus nodes for auto-jump
  final _focus1 = FocusNode();
  final _focus2 = FocusNode();
  final _focus3 = FocusNode();
  
  @override
  void initState() {
    super.initState();
    
    // If all data provided, skip to demographics verification
    if (widget.aadhaarNumber != null && widget.aadhaarNumber!.length == 12 &&
        widget.name != null && widget.name!.isNotEmpty &&
        widget.dob != null && widget.dob!.isNotEmpty &&
        widget.gender != null && widget.gender!.isNotEmpty) {
      _aadhaarNumber = widget.aadhaarNumber;
      _demographicsName = widget.name;
      _demographicsDob = widget.dob;
      _demographicsGender = widget.gender;
      _aadhaar1.text = widget.aadhaarNumber!.substring(0, 4);
      _aadhaar2.text = widget.aadhaarNumber!.substring(4, 8);
      _aadhaar3.text = widget.aadhaarNumber!.substring(8, 12);
      // Skip directly to demographics verification
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startDemographicsVerification();
      });
    } else if (widget.aadhaarNumber != null && widget.aadhaarNumber!.length == 12) {
      _aadhaarNumber = widget.aadhaarNumber;
      _aadhaar1.text = widget.aadhaarNumber!.substring(0, 4);
      _aadhaar2.text = widget.aadhaarNumber!.substring(4, 8);
      _aadhaar3.text = widget.aadhaarNumber!.substring(8, 12);
      // Skip Aadhaar entry, go to demographics
      _currentStep = _Step.demographicsEntry;
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
      case _Step.demographicsEntry:
        return 'Enter Your Details';
      case _Step.demographicsVerification:
        return 'Verifying Details';
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
    if (_isLoading && _currentStep != _Step.demographicsVerification) {
      return _buildLoadingScreen();
    }
    
    switch (_currentStep) {
      case _Step.aadhaarEntry:
        return _buildAadhaarEntry();
      case _Step.demographicsEntry:
        return _buildDemographicsEntry();
      case _Step.demographicsVerification:
        return _buildDemographicsVerification();
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
  
  // ==================== DEMOGRAPHICS ENTRY SCREEN ====================
  Widget _buildDemographicsEntry() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1976D2).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      size: 48,
                      color: Color(0xFF1976D2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Center(
                  child: Text(
                    'Enter your details as per Aadhaar',
                    style: TextStyle(fontSize: 16, color: Color(0xFF333333)),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Aadhaar: ${_maskAadhaar(_aadhaarNumber ?? '')}',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 32),
                
                // Full Name
                const Text(
                  'Full Name (as per Aadhaar)',
                  style: TextStyle(
                    fontSize: 14, 
                    fontWeight: FontWeight.w600, 
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Enter your full name',
                    prefixIcon: const Icon(Icons.person, color: Color(0xFF1976D2)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFBDBDBD)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  ),
                  onChanged: (_) => setState(() => _error = null),
                ),
                const SizedBox(height: 20),
                
                // Date of Birth
                const Text(
                  'Date of Birth',
                  style: TextStyle(
                    fontSize: 14, 
                    fontWeight: FontWeight.w600, 
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _dobController,
                  readOnly: true,
                  style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Select date of birth',
                    prefixIcon: const Icon(Icons.calendar_today, color: Color(0xFF1976D2)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFBDBDBD)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  ),
                  onTap: _selectDateOfBirth,
                ),
                const SizedBox(height: 20),
                
                // Gender
                const Text(
                  'Gender',
                  style: TextStyle(
                    fontSize: 14, 
                    fontWeight: FontWeight.w600, 
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildGenderOption('M', 'Male', Icons.male),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildGenderOption('F', 'Female', Icons.female),
                    ),
                  ],
                ),
                
                // Error message
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!, 
                            style: const TextStyle(color: Colors.red, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                  onPressed: _proceedFromDemographics,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Verify Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
  
  Widget _buildGenderOption(String value, String label, IconData icon) {
    final isSelected = _selectedGender == value;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedGender = value;
        _error = null;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF1976D2) : const Color(0xFFBDBDBD),
            width: isSelected ? 2 : 1,
          ),
          color: isSelected ? const Color(0xFF1976D2).withOpacity(0.05) : Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon, 
              color: isSelected ? const Color(0xFF1976D2) : Colors.grey,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? const Color(0xFF1976D2) : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _selectDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1920, 1, 1),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1976D2),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      final formatted = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      _dobController.text = formatted;
      setState(() => _error = null);
    }
  }
  
  // ==================== DEMOGRAPHICS VERIFICATION SCREEN ====================
  Widget _buildDemographicsVerification() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_error == null) ...[
              // Loading state
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1976D2)),
              ),
              const SizedBox(height: 32),
              const Text(
                'Verifying demographics...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Please wait while we verify your details',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ] else ...[
              // Error state
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Icon(
                  Icons.cancel,
                  size: 64,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Demographics Verification Failed',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.red),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _error = null;
                      _currentStep = _Step.demographicsEntry;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Try Again', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop(VerificationResult.failure(
                      errorCode: 'DEMOGRAPHICS_FAILED',
                      message: _error!,
                    ));
                  },
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
          ],
        ),
      ),
    );
  }
  
  // ==================== METHOD SELECTION SCREEN ====================
  Widget _buildMethodSelection() {
    final faceRDAvailable = _isFaceRDAvailable ?? true;
    
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
            enabled: true,
          ),
          const SizedBox(height: 16),
          
          // Face RD Option
          _buildMethodCard(
            icon: Icons.face_outlined,
            title: 'Face Authentication',
            subtitle: faceRDAvailable 
                ? 'Verify using Face RD biometric recognition'
                : 'Face RD app not installed',
            onTap: () {
              if (faceRDAvailable) {
                _selectFaceRD();
              } else {
                setState(() {
                  _error = 'Face RD app is not installed. Please install AadhaarFaceRD from ${Platform.isIOS ? "App Store" : "Play Store"}.';
                });
              }
            },
            enabled: faceRDAvailable,
          ),
          
          // Error message
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!, 
                      style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
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
    bool enabled = true,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Material(
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
                      Text(subtitle, style: TextStyle(fontSize: 13, color: enabled ? Colors.grey : Colors.red.shade300)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
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
      case _Step.demographicsEntry:
        setState(() => _currentStep = _Step.aadhaarEntry);
        break;
      case _Step.demographicsVerification:
        setState(() {
          _error = null;
          _currentStep = _Step.demographicsEntry;
        });
        break;
      case _Step.methodSelection:
        // Demographics already passed, go back to demographics entry
        setState(() => _currentStep = _Step.demographicsEntry);
        break;
      case _Step.faceAuth:
      case _Step.otpVerification:
        final config = IRCTCRailtelSDK.config;
        if (config.enableOtp) {
          setState(() => _currentStep = _Step.methodSelection);
        } else {
          // Go back to demographics entry if no method selection
          setState(() => _currentStep = _Step.demographicsEntry);
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
    setState(() {
      _error = null;
      _currentStep = _Step.demographicsEntry;
    });
  }
  
  void _proceedFromDemographics() {
    final name = _nameController.text.trim();
    final dob = _dobController.text.trim();
    final gender = _selectedGender;
    
    if (name.isEmpty) {
      setState(() => _error = 'Please enter your full name as per Aadhaar');
      return;
    }
    if (dob.isEmpty) {
      setState(() => _error = 'Please select your date of birth');
      return;
    }
    if (gender.isEmpty) {
      setState(() => _error = 'Please select your gender');
      return;
    }
    
    _demographicsName = name;
    _demographicsDob = dob;
    _demographicsGender = gender;
    
    _startDemographicsVerification();
  }
  
  // ==================== DEMOGRAPHICS VERIFICATION ====================
  Future<void> _startDemographicsVerification() async {
    setState(() {
      _error = null;
      _currentStep = _Step.demographicsVerification;
    });
    
    try {
      final response = await http.post(
        Uri.parse(SDKConfig.demoAuthUrl),
        headers: {
          'Content-Type': 'application/json',
          'token': SDKConfig.demoAuthToken,
        },
        body: jsonEncode({
          'aadhar_no': _aadhaarNumber,
          'name': _demographicsName,
          'dob': _demographicsDob,
          'gender': _demographicsGender,
        }),
      ).timeout(const Duration(seconds: 30));
      
      final json = jsonDecode(response.body);
      final status = json['status'] ?? 0;
      final message = json['message'] ?? 'Demographics verification failed';
      final token = json['token'];
      
      if (status == 1) {
        // Demographics passed
        _demographicsToken = token;
        _goToMethodSelectionOrFaceAuth();
      } else {
        // Demographics failed
        if (token != null) {
          _demographicsToken = token;
        }
        setState(() {
          _error = message;
        });
      }
    } on Exception catch (e) {
      String errorMsg = e.toString();
      if (errorMsg.contains('SocketTimeoutException') || errorMsg.contains('TimeoutException')) {
        errorMsg = 'Server timeout. Please try again.';
      } else if (errorMsg.contains('SocketException') || errorMsg.contains('UnknownHostException')) {
        errorMsg = 'No internet connection.';
      } else {
        errorMsg = 'Demographics verification failed: ${errorMsg.replaceFirst('Exception: ', '')}';
      }
      setState(() {
        _error = errorMsg;
      });
    }
  }
  
  void _goToMethodSelectionOrFaceAuth() {
    final config = IRCTCRailtelSDK.config;
    if (config.enableOtp) {
      // Check Face RD availability before showing method selection
      _checkFaceRDAndShowMethodSelection();
    } else {
      // Skip directly to Face Auth if OTP not enabled
      _selectFaceRD();
    }
  }
  
  Future<void> _checkFaceRDAndShowMethodSelection() async {
    try {
      final available = await FaceRDService.isFaceRDAvailable();
      if (mounted) {
        setState(() {
          _isFaceRDAvailable = available;
          _error = null;
          _currentStep = _Step.methodSelection;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isFaceRDAvailable = false;
          _error = null;
          _currentStep = _Step.methodSelection;
        });
      }
    }
  }
  
  void _selectOtp() {
    _verificationMethod = VerificationMethod.otp;
    setState(() {
      _error = null;
      _currentStep = _Step.otpVerification;
    });
    _sendOtp();
  }
  
  void _selectFaceRD() {
    _verificationMethod = VerificationMethod.faceRD;
    setState(() {
      _error = null;
      _currentStep = _Step.faceAuth;
    });
  }
  
  // ==================== FACE RD CAPTURE ====================
  Future<void> _startFaceCapture() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      // Capture face using Face RD app with KYC enabled
      // The native plugin handles:
      //   Android: startActivityForResult with Face RD intent
      //   iOS: URL Scheme launch (FaceRDLib://) per UIDAI iOS API Spec
      final pidData = await FaceRDService.capture(
        isDemo: !IRCTCRailtelSDK.config.isProduction,
        enableKyc: true,
      );
      
      // Verify with API
      await _verifyFaceWithAPI(pidData);
      
    } catch (e) {
      String errorMsg = e.toString().replaceFirst('Exception: ', '');
      
      // Provide helpful messages for common errors
      if (errorMsg.contains('not installed') || errorMsg.contains('NOT_INSTALLED')) {
        errorMsg = 'Face RD app is not installed.\n\nPlease install "Aadhaar Face RD" from ${Platform.isIOS ? "App Store" : "Play Store"} and try again.';
      } else if (errorMsg.contains('cancelled') || errorMsg.contains('CANCELLED')) {
        errorMsg = 'Face capture was cancelled. Please try again.';
      }
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = errorMsg;
        });
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
  
  // ==================== HELPERS ====================
  String _maskAadhaar(String aadhaar) {
    if (aadhaar.length != 12) return aadhaar;
    return 'XXXX XXXX ${aadhaar.substring(8)}';
  }
  
  @override
  void dispose() {
    _aadhaar1.dispose();
    _aadhaar2.dispose();
    _aadhaar3.dispose();
    _nameController.dispose();
    _dobController.dispose();
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
  demographicsEntry,
  demographicsVerification,
  methodSelection,
  faceAuth,
  otpVerification,
  result,
}
