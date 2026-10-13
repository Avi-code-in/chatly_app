import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:country_code_picker/country_code_picker.dart';
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
  String _countryCode = '+91';
  bool _codeSent = false;
  bool _loading = false;
  bool _isNewUser = false;
  String? _error;
  String? _verificationId;

  final _auth = FirebaseAuth.instance;
  final _chatService = ChatService();

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 10) {
      setState(() => _error = 'Enter valid phone number');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    await _auth.verifyPhoneNumber(
      phoneNumber: '$_countryCode$phone',
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
      final uid = userCredential.user!.uid;
      final existingUser = await _chatService.getUserById(uid);

      if (existingUser == null) {
        setState(() {
          _isNewUser = true;
          _loading = false;
        });
        return;
      }

      await _chatService.updateOnlineStatus(true);
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

  Future<void> _saveNameAndContinue() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your name');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    await _chatService.createUserIfNotExistsWithPhone(
      _nameController.text.trim(),
      '$_countryCode${_phoneController.text.trim()}',
    );
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ChatListScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Stack(
        children: [
          // Bottom wave decoration
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary.withOpacity(0.05),
                    AppColors.primary.withOpacity(0.15),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(120),
                  topRight: Radius.circular(120),
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),

                  // Logo
                  Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.chat_bubble,
                        color: Colors.white,
                        size: 50,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Center(
                    child: Text(
                      'Chatly',
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      'Connect. Chat. Be Closer.',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Illustration
                  Center(
                    child: SizedBox(
                      height: 100,
                      child: Stack(
                        children: [
                          Positioned(
                            left: 30,
                            child: Container(
                              width: 80,
                              height: 60,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    AppColors.primary,
                                    AppColors.primaryDark
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(Icons.chat_bubble,
                                  color: Colors.white, size: 30),
                            ),
                          ),
                          Positioned(
                            right: 30,
                            top: 20,
                            child: Container(
                              width: 70,
                              height: 50,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Icon(Icons.chat_bubble,
                                  color: AppColors.primary.withOpacity(0.5),
                                  size: 25),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  if (_isNewUser) ...[
                    TextField(
                      controller: _nameController,
                      decoration: _inputDecoration('Your name', Icons.person_outline),
                    ),
                    const SizedBox(height: 20),
                    _primaryButton('Continue', _saveNameAndContinue),
                  ] else if (!_codeSent) ...[
                    // Phone input with country picker
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          CountryCodePicker(
                            onChanged: (country) {
                              setState(() {
                                _countryCode = country.dialCode ?? '+91';
                              });
                            },
                            initialSelection: 'IN',
                            favorite: const ['+91', 'IN'],
                            showCountryOnly: false,
                            showOnlyCountryWhenClosed: false,
                            alignLeft: false,
                            padding: EdgeInsets.zero,
                            flagWidth: 28,
                            textStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 30,
                            color: Colors.grey[300],
                          ),
                          Expanded(
                            child: TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                hintText: 'Enter your phone number',
                                hintStyle: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 15,
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 18),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _primaryButton('Continue', _sendOtp),
                  ] else ...[
                    Text(
                      'OTP sent to $_countryCode ${_phoneController.text}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        letterSpacing: 8,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        hintText: '------',
                        counterText: '',
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _primaryButton('Verify & Login', _verifyOtp),
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

                  const SizedBox(height: 24),
                  const Center(
                    child: Text(
                      'By continuing, you agree to our\nTerms of Service & Privacy Policy',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.textSecondary),
      filled: true,
      fillColor: AppColors.background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    );
  }

  Widget _primaryButton(String text, VoidCallback onPressed) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _loading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                text,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}
