import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/chat_service.dart';
import '../theme.dart';
import 'chat_list_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _nameController = TextEditingController();
  bool _codeSent = false;
  bool _loading = false;
  String? _error;
  String? _verificationId;

  final _auth = FirebaseAuth.instance;
  final _chatService = ChatService();

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.length != 10) {
      setState(() => _error = 'Enter valid 10-digit phone number');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    await _auth.verifyPhoneNumber(
      phoneNumber: '+91$phone',
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _auth.signInWithCredential(credential);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ChatListScreen()),
          );
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() {
          _error = e.message ?? 'Verification failed';
          _loading = false;
        });
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId = verificationId;
          _codeSent = true;
          _loading = false;
        });
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _error = 'Enter valid 6-digit OTP');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      final userCredential = await _auth.signInWithCredential(credential);

      // Check if new user
      final uid = userCredential.user!.uid;
      final existingUser = await _chatService.getUserById(uid);

      if (existingUser == null) {
        // New user - need name
        if (_nameController.text.trim().isEmpty) {
          setState(() {
            _error = 'Please enter your name';
            _loading = false;
          });
          return;
        }
        await _chatService.createUserIfNotExistsWithPhone(
          _nameController.text.trim(),
          '+91${_phoneController.text.trim()}',
        );
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ChatListScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Invalid OTP. Please try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),
              Center(
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.chat_bubble,
                    color: Colors.white,
                    size: 55,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Center(
                child: Text(
                  'Chatly',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Simple. Fast. Connected.',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 48),

              if (!_codeSent) ...[
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  decoration: InputDecoration(
                    hintText: 'Phone number',
                    prefixIcon: const Icon(Icons.phone,
                        color: AppColors.textSecondary),
                    prefixText: '+91 ',
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 18),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _sendOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Send OTP',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ] else ...[
                Text(
                  'OTP sent to +91 ${_phoneController.text}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    hintText: 'Enter 6-digit OTP',
                    prefixIcon: const Icon(Icons.lock_outline,
                        color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 18),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: 'Your name',
                    prefixIcon: const Icon(Icons.person_outline,
                        color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 18),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _verifyOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Verify & Login',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() {
                    _codeSent = false;
                    _otpController.clear();
                  }),
                  child: const Text('Change phone number'),
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
