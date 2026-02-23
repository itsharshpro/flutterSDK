import 'package:flutter/material.dart';
import 'package:irctc_railtel_sdk/irctc_railtel_sdk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize SDK with configuration
  await IRCTCRailtelSDK.initialize(
    config: SDKConfig(
      environment: Environment.demo,  // Use Environment.demo for testing
      enableOtp: true,   // Enable OTP verification option
    ),
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IRCTCRailtel Sample',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1976D2)),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _status = '';
  Color _statusColor = Colors.grey;
  String? _transactionId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo/Title
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1976D2).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.verified_user,
                  size: 60,
                  color: Color(0xFF1976D2),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'IRCTCRailtel SDK Demo',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1976D2),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Aadhaar Verification Sample App',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 48),
              
              // Verify Button
              ElevatedButton(
                onPressed: _startVerification,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(220, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  elevation: 4,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fingerprint),
                    SizedBox(width: 8),
                    Text(
                      'Verify Aadhaar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Status Display
              if (_status.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _statusColor.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _status,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: _statusColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_transactionId != null) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Transaction ID:',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          _transactionId!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startVerification() async {
    // Clear previous status
    setState(() {
      _status = '';
      _transactionId = null;
    });
    
    // Start verification flow
    final result = await IRCTCRailtelSDK.startVerification(context);
    
    setState(() {
      if (result.isSuccess) {
        _status = '✅ Verification Successful!\nMethod: ${result.data?.method.name.toUpperCase()}';
        if (result.data?.name != null) {
          _status += '\nName: ${result.data!.name}';
        }
        _statusColor = Colors.green;
        _transactionId = result.data?.transactionId;
      } else if (result.isCancelled) {
        _status = 'Verification cancelled by user';
        _statusColor = Colors.grey;
      } else {
        _status = '❌ Verification Failed\n${result.errorMessage ?? "Unknown error"}';
        _statusColor = Colors.red;
      }
    });
  }
}
