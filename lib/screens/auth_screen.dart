import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isLogin = true;
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  final _auth = FirebaseAuth.instance;
  final _chatService = ChatService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
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
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
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
      String msg = 'Authentication failed';
      switch (e.code) {
        case 'user-not-found':
          msg = 'No account found with this email';
          break;
        case 'wrong-password':
          msg = 'Incorrect password';
          break;
        case 'email-already-in-use':
          msg = 'This email is already registered';
          break;
        case 'invalid-email':
          msg = 'Please enter a valid email';
          break;
        case 'weak-password':
          msg = 'Password is too weak';
          break;
        default:
          msg = e.message ?? msg;
      }
      setState(() => _error = msg);
    } catch (e) {
      setState(() => _error = 'Something went wrong');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goHome() async {
    if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FF),
      body: Stack(
        children: [
          // ==================== BACKGROUND ORBS ====================
          Positioned(
            top: -100,
            left: -80,
            child: _orb(250, const Color(0xFFC9D6FF), 0.5),
          ),
          Positioned(
            top: 100,
            right: -100,
            child: _orb(220, const Color(0xFFD9C7FF), 0.4),
          ),
          Positioned(
            bottom: 200,
            left: -60,
            child: _orb(180, const Color(0xFFB8D4FF), 0.3),
          ),

          // ==================== FLOATING CHAT BUBBLES ====================
          Positioned(
            top: 180,
            left: 20,
            child: _floatingBubble(
              size: 50,
              angle: -0.3,
              colors: [const Color(0xFF4A90E2), const Color(0xFF2874C7)],
            ),
          ),
          Positioned(
            top: 220,
            right: 30,
            child: _floatingBubble(
              size: 40,
              angle: 0.25,
              colors: [const Color(0xFF9C6BFF), const Color(0xFF7C4DFF)],
            ),
          ),
          Positioned(
            top: 130,
            right: 10,
            child: _star(const Color(0xFFB39DFF)),
          ),
          Positioned(
            top: 280,
            left: 60,
            child: _star(const Color(0xFF7BAAF7), size: 10),
          ),
          Positioned(
            top: 200,
            right: 90,
            child: _star(const Color(0xFF9C6BFF), size: 12),
          ),

          // ==================== BOTTOM WAVE ====================
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CustomPaint(
              size: Size(MediaQuery.of(context).size.width, 180),
              painter: _WavePainter(),
            ),
          ),

          // ==================== MAIN CONTENT ====================
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // ==================== LOGO ====================
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF4A90E2), Color(0xFF7C4DFF)],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4A90E2).withOpacity(0.35),
                          blurRadius: 30,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Inner white bubble
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _dot(const Color(0xFF4A90E2)),
                              const SizedBox(width: 4),
                              _dot(const Color(0xFF5B7BE2)),
                              const SizedBox(width: 4),
                              _dot(const Color(0xFF7C4DFF)),
                            ],
                          ),
                        ),
                        // Small dot overlay top-left
                        Positioned(
                          top: 12,
                          left: 12,
                          child: _dot(Colors.white.withOpacity(0.7), 6),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ==================== CHATLY TEXT ====================
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -2,
                      ),
                      children: [
                        TextSpan(
                          text: 'Chat',
                          style: TextStyle(color: Color(0xFF0B1F3A)),
                        ),
                        TextSpan(
                          text: 'ly',
                          style: TextStyle(
                            foreground: Paint()
                              ..shader = LinearGradient(
                                colors: [Color(0xFF4A90E2), Color(0xFF7C4DFF)],
                              ).createShader(
                                  const Rect.fromLTWH(0, 0, 60, 60)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 6),

                  // ==================== TAGLINE ====================
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _tagline('Chat'),
                      _tagDot(),
                      _tagline('Connect'),
                      _tagDot(),
                      _tagline('Share'),
                    ],
                  ),

                  const SizedBox(height: 36),

                  // ==================== WELCOME ====================
                  Text(
                    _isLogin ? 'WELCOME BACK' : 'GET STARTED',
                    style: const TextStyle(
                      color: Color(0xFF7C4DFF),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Login to Chatly
                  _isLogin
                      ? RichText(
                          text: const TextSpan(
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              color: Color(0xFF0B1F3A),
                            ),
                            children: [
                              TextSpan(text: 'Login to '),
                              TextSpan(
                                text: 'Chatly',
                                style: TextStyle(
                                  foreground: Paint()
                                    ..shader = LinearGradient(
                                      colors: [
                                        Color(0xFF4A90E2),
                                        Color(0xFF7C4DFF)
                                      ],
                                    ).createShader(
                                        const Rect.fromLTWH(0, 0, 100, 40)),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const Text(
                          'Create your account',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: Color(0xFF0B1F3A),
                          ),
                        ),

                  const SizedBox(height: 10),

                  Text(
                    _isLogin
                        ? 'Your conversations, your world.\nLet\'s get back to it.'
                        : 'Join Chatly today.\nConnect with your friends.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.55),
                      fontSize: 14,
                      height: 1.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // ==================== NAME (Signup) ====================
                  if (!_isLogin) ...[
                    _inputCard(
                      controller: _nameController,
                      hint: 'Your name',
                      subtitle: 'Enter your name',
                      icon: Icons.person_outline,
                      iconColor: const Color(0xFF4A90E2),
                      iconBg: const Color(0xFFE8F0FF),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // ==================== EMAIL ====================
                  _inputCard(
                    controller: _emailController,
                    hint: 'Email address',
                    subtitle: 'Enter your email to continue',
                    icon: Icons.email_outlined,
                    iconColor: const Color(0xFF4A90E2),
                    iconBg: const Color(0xFFE8F0FF),
                    keyboard: TextInputType.emailAddress,
                  ),

                  const SizedBox(height: 14),

                  // ==================== PASSWORD ====================
                  _inputCard(
                    controller: _passwordController,
                    hint: 'Password',
                    subtitle: 'Enter your password',
                    icon: Icons.lock_outline,
                    iconColor: const Color(0xFF7C4DFF),
                    iconBg: const Color(0xFFEDE5FF),
                    obscure: _obscurePassword,
                    suffix: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: const Color(0xFF8F92A1),
                        size: 22,
                      ),
                      onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword),
                    ),
                  ),

                  // ==================== ERROR ====================
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Colors.red.withOpacity(0.2), width: 1),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.red, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(_error!,
                                style: const TextStyle(
                                    color: Colors.red, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ==================== LOGIN BUTTON ====================
                  _loginButton(),

                  const SizedBox(height: 24),

                  // ==================== OR DIVIDER ====================
                  Row(
                    children: [
                      Expanded(
                          child: Container(
                              height: 1,
                              color: Colors.black.withOpacity(0.08))),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14),
                        child: Text('OR',
                            style: TextStyle(
                              color: Color(0xFF8F92A1),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                            )),
                      ),
                      Expanded(
                          child: Container(
                              height: 1,
                              color: Colors.black.withOpacity(0.08))),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ==================== SIGN UP TOGGLE ====================
                  GestureDetector(
                    onTap: () => setState(() {
                      _isLogin = !_isLogin;
                      _error = null;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.black.withOpacity(0.05),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4A90E2).withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.verified_user_outlined,
                              color: Color(0xFF4A90E2),
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _isLogin
                                ? 'Don\'t have an account? '
                                : 'Already have an account? ',
                            style: TextStyle(
                              color: Colors.black.withOpacity(0.6),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            _isLogin ? 'Sign up' : 'Login',
                            style: const TextStyle(
                              color: Color(0xFF4A90E2),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ==================== PRIVACY FOOTER ====================
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4A90E2).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.lock_outline,
                            color: Color(0xFF4A90E2),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Your data is safe and encrypted. Only your approved contacts can message you.',
                            style: TextStyle(
                              color: Colors.black.withOpacity(0.5),
                              fontSize: 12.5,
                              height: 1.4,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== LOGIN BUTTON ====================
  Widget _loginButton() {
    return Container(
      height: 58,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A90E2), Color(0xFF7C4DFF)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A90E2).withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _loading ? null : _submit,
          borderRadius: BorderRadius.circular(30),
          child: Center(
            child: _loading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isLogin ? 'Login' : 'Create Account',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.arrow_forward,
                          color: Colors.white, size: 22),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ==================== INPUT CARD ====================
  Widget _inputCard({
    required TextEditingController controller,
    required String hint,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    bool obscure = false,
    TextInputType? keyboard,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            // Icon box
            Container(
              width: 52,
              height: 52,
              margin: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 4),
            // Text field
            Expanded(
              child: TextField(
                controller: controller,
                obscureText: obscure,
                keyboardType: keyboard,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF0B1F3A),
                ),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(
                    color: Color(0xFF0B1F3A),
                    fontSize: 15.5,
                    fontWeight: FontWeight.w500,
                  ),
                  labelText: subtitle,
                  labelStyle: const TextStyle(
                    color: Color(0xFF8F92A1),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                  ),
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                ),
              ),
            ),
            if (suffix != null) suffix,
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  // ==================== HELPERS ====================
  Widget _orb(double size, Color color, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withOpacity(opacity), color.withOpacity(0)],
        ),
      ),
    );
  }

  Widget _floatingBubble({
    required double size,
    required double angle,
    required List<Color> colors,
  }) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(size * 0.35),
          boxShadow: [
            BoxShadow(
              color: colors.first.withOpacity(0.35),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _dot(Colors.white.withOpacity(0.95), size * 0.12),
              SizedBox(width: size * 0.06),
              _dot(Colors.white.withOpacity(0.95), size * 0.12),
              SizedBox(width: size * 0.06),
              _dot(Colors.white.withOpacity(0.95), size * 0.12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _star(Color color, {double size = 14}) {
    return Icon(Icons.star, color: color, size: size);
  }

  Widget _dot(Color color, [double size = 8]) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _tagline(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        color: Color(0xFF5A6B8A),
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _tagDot() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      width: 4,
      height: 4,
      decoration: const BoxDecoration(
        color: Color(0xFF5A6B8A),
        shape: BoxShape.circle,
      ),
    );
  }
}

// ==================== WAVE PAINTER ====================
class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF7C4DFF), Color(0xFF4A90E2)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final paint2 = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF4A90E2), Color(0xFF7C4DFF)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..color = const Color(0xFF4A90E2).withOpacity(0.4);

    // Back wave
    final path1 = Path();
    path1.moveTo(0, size.height * 0.5);
    path1.quadraticBezierTo(size.width * 0.25, size.height * 0.2,
        size.width * 0.5, size.height * 0.4);
    path1.quadraticBezierTo(
        size.width * 0.75, size.height * 0.6, size.width, size.height * 0.3);
    path1.lineTo(size.width, size.height);
    path1.lineTo(0, size.height);
    path1.close();
    canvas.drawPath(path1, paint1..color = const Color(0xFF7C4DFF).withOpacity(0.55));

    // Front wave
    final path2 = Path();
    path2.moveTo(0, size.height * 0.7);
    path2.quadraticBezierTo(size.width * 0.3, size.height * 0.4,
        size.width * 0.6, size.height * 0.6);
    path2.quadraticBezierTo(
        size.width * 0.85, size.height * 0.75, size.width, size.height * 0.55);
    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
