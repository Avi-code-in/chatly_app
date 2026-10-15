import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:country_code_picker/country_code_picker.dart';
import '../services/chat_service.dart';
import '../theme.dart';
import 'chat_list_screen.dart';
import 'setup_username_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // Controllers
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  // State
  bool _usePhone = true;
  bool _isLogin = true;
  bool _codeSent = false;
  bool _loading = false;
  bool _isNewUser = false;
  bool _obscurePassword = true;
  String _countryCode = '+91';
  String? _error;
  String? _verificationId;

  final _auth = FirebaseAuth.instance;
  final _chatService = ChatService();

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // ============ PHONE AUTH ============
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

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: '$_countryCode$phone',
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
          if (mounted) _goHome();
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
    } catch (e) {
      setState(() {
        _error = 'Phone auth unavailable. Please use email.';
        _loading = false;
      });
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _error = 'Enter 6-digit OTP');
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
      final userCred = await _auth.signInWithCredential(credential);
      final uid = userCred.user!.uid;
      final existing = await _chatService.getUserById(uid);
      if (existing == null) {
        setState(() {
          _isNewUser = true;
          _loading = false;
        });
        return;
      }
      await _chatService.updateOnlineStatus(true);
      _goHome();
    } catch (e) {
      setState(() {
        _error = 'Invalid OTP';
        _loading = false;
      });
    }
  }

  // ============ EMAIL AUTH ============
  Future<void> _emailAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please fill all fields');
      return;
    }
    if (!_isLogin && _nameController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your name');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_isLogin) {
        await _auth.signInWithEmailAndPassword(
            email: email, password: password);
        await _chatService.updateOnlineStatus(true);
      } else {
        final cred = await _auth.createUserWithEmailAndPassword(
            email: email, password: password);
        await _chatService.createUserIfNotExists(
            _nameController.text.trim(), cred.user!.uid);
      }
      _goHome();
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? 'Auth failed');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize();
      final googleUser = await googleSignIn.authenticate();
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      final userCred = await _auth.signInWithCredential(credential);
      final uid = userCred.user!.uid;
      final existing = await _chatService.getUserById(uid);
      if (existing == null) {
        await _chatService.createUserIfNotExists(
            userCred.user!.displayName ?? 'User', uid);
      } else {
        await _chatService.updateOnlineStatus(true);
      }
      _goHome();
    } catch (e) {
      setState(() => _error = 'Google sign-in failed');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goHome() async {
    if (!mounted) return;
    // Check if user has username
    final user = await _chatService.getCurrentUser().first;
    if (!mounted) return;
    if (user == null || user.username.isEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SetupUsernameScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ChatListScreen()),
      );
    }
  }

  // ============ BUILD ============
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      body: Stack(
        children: [
          // Decorative orbs
          Positioned(
            top: -100,
            right: -100,
            child: _orb(280, const Color(0xFF8EC5FC), 0.4),
          ),
          Positioned(
            top: 20,
            left: -80,
            child: _orb(200, const Color(0xFFB8D4FF), 0.3),
          ),
          Positioned(
            bottom: -120,
            left: -80,
            child: _orb(320, const Color(0xFF8EC5FC), 0.35),
          ),
          Positioned(
            bottom: -60,
            right: -80,
            child: _orb(240, const Color(0xFFB8D4FF), 0.3),
          ),

          // Main content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 40),

                  // LOGO
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2196F3).withOpacity(0.3),
                          blurRadius: 40,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: Image.asset(
                        'assets/icon/icon.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                            ),
                            borderRadius: BorderRadius.circular(32),
                          ),
                          child: const Icon(Icons.chat_bubble,
                              color: Colors.white, size: 60),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // CHATLY (Chat + ly in blue)
                  RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'Chat',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1A1A2E),
                            letterSpacing: -2,
                          ),
                        ),
                        TextSpan(
                          text: 'ly',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF2196F3),
                            letterSpacing: -2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Tagline
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _tagline('Chat'),
                      _dot(),
                      _tagline('Connect'),
                      _dot(),
                      _tagline('Share'),
                    ],
                  ),
                  const SizedBox(height: 48),

                  // LOGIN HEADING
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _usePhone
                          ? 'Enter your phone number to continue'
                          : _isLogin
                              ? 'Enter your email to continue'
                              : 'Create a new account',
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF8F92A1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // FORM
                  if (_isNewUser)
                    _buildNameForm()
                  else if (_usePhone)
                    _codeSent ? _buildOtpForm() : _buildPhoneForm()
                  else
                    _buildEmailForm(),

                  const SizedBox(height: 24),

                  // Error
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                  color: Colors.red, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Toggle between phone/email
                  if (!_codeSent && !_isNewUser)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _usePhone = !_usePhone;
                          _error = null;
                        });
                      },
                      child: Text(
                        _usePhone
                            ? 'Use email instead'
                            : 'Use phone number instead',
                        style: const TextStyle(
                          color: Color(0xFF2196F3),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Decorative orb
  Widget _orb(double size, Color color, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withOpacity(opacity),
            color.withOpacity(0),
          ],
        ),
      ),
    );
  }

  Widget _tagline(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        color: Color(0xFF8F92A1),
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _dot() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      width: 4,
      height: 4,
      decoration: const BoxDecoration(
        color: Color(0xFF8F92A1),
        shape: BoxShape.circle,
      ),
    );
  }

  // ============ FORM BUILDERS ============
  Widget _buildPhoneForm() {
    return Column(
      children: [
        // Phone input with flag
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF2196F3).withOpacity(0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2196F3).withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              CountryCodePicker(
                onChanged: (c) => setState(() {
                  _countryCode = c.dialCode ?? '+91';
                }),
                initialSelection: 'IN',
                favorite: const ['+91', 'IN'],
                showCountryOnly: false,
                showOnlyCountryWhenClosed: false,
                alignLeft: false,
                padding: const EdgeInsets.only(left: 8, right: 4),
                flagWidth: 26,
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              Container(
                width: 1,
                height: 28,
                color: Colors.grey[300],
              ),
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Phone number',
                    hintStyle: TextStyle(
                      color: Color(0xFF8F92A1),
                      fontSize: 15,
                      fontWeight: FontWeight.normal,
                      letterSpacing: 0,
                    ),
                    counterText: '',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 16, vertical: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _primaryButton(
          'Continue',
          _sendOtp,
          icon: Icons.arrow_forward,
        ),
        const SizedBox(height: 24),
        _privacyText(),
      ],
    );
  }

  Widget _buildOtpForm() {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'OTP sent to $_countryCode ${_phoneController.text}',
            style: const TextStyle(
              color: Color(0xFF8F92A1),
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF2196F3).withOpacity(0.15),
              width: 1.5,
            ),
          ),
          child: TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              letterSpacing: 12,
              fontWeight: FontWeight.bold,
            ),
            decoration: const InputDecoration(
              hintText: '------',
              hintStyle: TextStyle(
                color: Color(0xFF8F92A1),
                letterSpacing: 12,
                fontSize: 24,
              ),
              counterText: '',
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 20),
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
    );
  }

  Widget _buildEmailForm() {
    return Column(
      children: [
        if (!_isLogin) ...[
          _textField(
            controller: _nameController,
            hint: 'Your name',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 14),
        ],
        _textField(
          controller: _emailController,
          hint: 'Email',
          icon: Icons.email_outlined,
          keyboard: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),
        _textField(
          controller: _passwordController,
          hint: 'Password',
          icon: Icons.lock_outline,
          obscure: _obscurePassword,
          suffix: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: const Color(0xFF8F92A1),
              size: 20,
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        const SizedBox(height: 20),
        _primaryButton(
          _isLogin ? 'Login' : 'Create Account',
          _emailAuth,
          icon: Icons.arrow_forward,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey[300])),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('OR',
                  style: TextStyle(
                      color: Color(0xFF8F92A1),
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
            Expanded(child: Divider(color: Colors.grey[300])),
          ],
        ),
        const SizedBox(height: 20),
        _googleButton(),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() {
            _isLogin = !_isLogin;
            _error = null;
          }),
          child: Text(
            _isLogin
                ? "Don't have an account? Sign up"
                : "Already have an account? Login",
            style: const TextStyle(
              color: Color(0xFF2196F3),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNameForm() {
    return Column(
      children: [
        _textField(
          controller: _nameController,
          hint: 'Your name',
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 20),
        _primaryButton('Continue', () async {
          if (_nameController.text.trim().isEmpty) {
            setState(() => _error = 'Please enter your name');
            return;
          }
          setState(() => _loading = true);
          await _chatService.createUserIfNotExists(
            _nameController.text.trim(),
            _auth.currentUser!.uid,
          );
          _goHome();
        }),
      ],
    );
  }

  // ============ COMPONENTS ============
  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboard,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2196F3).withOpacity(0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2196F3).withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboard,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: Color(0xFF8F92A1),
            fontSize: 15,
            fontWeight: FontWeight.normal,
          ),
          prefixIcon: Icon(icon, color: const Color(0xFF2196F3), size: 22),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  }

  Widget _primaryButton(String text, VoidCallback onPressed,
      {IconData? icon}) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2196F3).withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _loading ? null : onPressed,
          borderRadius: BorderRadius.circular(30),
          child: Center(
            child: _loading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      if (icon != null) ...[
                        const SizedBox(width: 10),
                        Icon(icon, color: Colors.white, size: 22),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _googleButton() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2196F3).withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _loading ? null : _googleSignIn,
          borderRadius: BorderRadius.circular(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: const Center(
                  child: Text(
                    'G',
                    style: TextStyle(
                      color: Color(0xFF4285F4),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Continue with Google',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _privacyText() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF2196F3).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.lock_outline,
            color: Color(0xFF2196F3),
            size: 16,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            "Your phone number won't be shared with anyone else. It's used only for verification.",
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF8F92A1),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
