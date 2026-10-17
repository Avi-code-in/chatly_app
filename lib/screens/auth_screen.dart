import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/chat_service.dart';
import 'chat_list_screen.dart';
import 'setup_username_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isLogin = true;
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;
  late AnimationController _floatCtrl;

  final _auth = FirebaseAuth.instance;
  final _chatService = ChatService();

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _floatCtrl.dispose();
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
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F3FF),
      body: Stack(
        children: [
          // FADED WAVE IN BACKGROUND
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.4,
                child: SizedBox(
                  height: 250,
                  child: CustomPaint(painter: _WavePainter()),
                ),
              ),
            ),
          ),
          // ============ BACKGROUND ORBS ============
          Positioned(
            top: -100,
            left: -80,
            child: _orb(280, const Color(0xFFD5DDFF), 0.7),
          ),
          Positioned(
            top: 20,
            right: -100,
            child: _orb(260, const Color(0xFFE5D9FF), 0.6),
          ),
          Positioned(
            top: h * 0.4,
            left: -60,
            child: _orb(200, const Color(0xFFD5DDFF), 0.4),
          ),

          // ============ SPARKLES / STARS ============
          Positioned(top: 60, left: 60, child: _sparkle(20, 0.5)),
          Positioned(top: 90, right: 50, child: _sparkle(24, 0.6)),
          Positioned(top: 200, left: 30, child: _sparkle(14, 0.4)),
          Positioned(top: 250, right: 30, child: _sparkle(18, 0.5)),
          Positioned(top: 130, left: 100, child: _sparkle(12, 0.3)),
          Positioned(top: 320, right: 80, child: _sparkle(16, 0.4)),

          // ============ FLOATING 3D BUBBLES ============
          // Left side big bubble
          Positioned(
            top: h * 0.14,
            left: 8,
            child: AnimatedBuilder(
              animation: _floatCtrl,
              builder: (_, c) => Transform.translate(
                offset: Offset(0, math.sin(_floatCtrl.value * math.pi * 2) * 6),
                child: Transform.rotate(
                  angle: -0.25,
                  child: _bubble3D(
                    size: 78,
                    colors: [const Color(0xFF5BA9FF), const Color(0xFF2874C7)],
                    dotColor: Colors.white,
                  ),
                ),
              ),
            ),
          ),

          // Right side big bubble
          Positioned(
            top: h * 0.2,
            right: 12,
            child: AnimatedBuilder(
              animation: _floatCtrl,
              builder: (_, c) => Transform.translate(
                offset: Offset(
                    0, math.cos(_floatCtrl.value * math.pi * 2) * 8),
                child: Transform.rotate(
                  angle: 0.3,
                  child: _bubble3D(
                    size: 64,
                    colors: [const Color(0xFFA78BFA), const Color(0xFF7C4DFF)],
                    dotColor: Colors.white,
                  ),
                ),
              ),
            ),
          ),

          // ============ MAIN CONTENT ============
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // "Better Conversations Together" handwritten
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Transform.rotate(
                        angle: -0.08,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            ShaderMask(
                              shaderCallback: (b) => const LinearGradient(
                                colors: [
                                  Color(0xFF4A90E2),
                                  Color(0xFF7C4DFF)
                                ],
                              ).createShader(b),
                              child: const Text(
                                'Better',
                                style: TextStyle(
                                  fontFamily: 'cursive',
                                  fontSize: 22,
                                  color: Colors.white,
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            ShaderMask(
                              shaderCallback: (b) => const LinearGradient(
                                colors: [
                                  Color(0xFF4A90E2),
                                  Color(0xFF7C4DFF)
                                ],
                              ).createShader(b),
                              child: const Text(
                                'Conversations',
                                style: TextStyle(
                                  fontFamily: 'cursive',
                                  fontSize: 20,
                                  color: Colors.white,
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            ShaderMask(
                              shaderCallback: (b) => const LinearGradient(
                                colors: [
                                  Color(0xFF4A90E2),
                                  Color(0xFF7C4DFF)
                                ],
                              ).createShader(b),
                              child: const Text(
                                'Together',
                                style: TextStyle(
                                  fontFamily: 'cursive',
                                  fontSize: 20,
                                  color: Colors.white,
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              width: 90,
                              height: 1.5,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF4A90E2),
                                    Color(0xFF7C4DFF)
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ==================== 3D LOGO ====================
                  _logo3D(),
                  const SizedBox(height: 22),

                  // ==================== CHATLY TEXT ====================
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Chat',
                        style: TextStyle(
                          fontSize: 54,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -2.5,
                          color: Color(0xFF0B1F3A),
                          height: 1,
                        ),
                      ),
                      ShaderMask(
                        shaderCallback: (b) => const LinearGradient(
                          colors: [Color(0xFF4A90E2), Color(0xFF7C4DFF)],
                        ).createShader(b),
                        child: const Text(
                          'ly',
                          style: TextStyle(
                            fontSize: 54,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -2.5,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // ==================== TAGLINE ====================
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _tagText('Chat'),
                      _tagDot(),
                      _tagText('Connect'),
                      _tagDot(),
                      _tagText('Share'),
                    ],
                  ),

                  const SizedBox(height: 42),

                  // ==================== WELCOME BACK ====================
                  Text(
                    _isLogin ? 'WELCOME BACK' : 'GET STARTED',
                    style: const TextStyle(
                      color: Color(0xFF7C4DFF),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ==================== LOGIN TO CHATLY ====================
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isLogin ? 'Login to ' : 'Create ',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                          color: Color(0xFF0B1F3A),
                          height: 1.1,
                        ),
                      ),
                      ShaderMask(
                        shaderCallback: (b) => const LinearGradient(
                          colors: [Color(0xFF4A90E2), Color(0xFF7C4DFF)],
                        ).createShader(b),
                        child: Text(
                          _isLogin ? 'Chatly' : 'Account',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  Text(
                    _isLogin
                        ? 'Your conversations, your world.\nLet\'s get back to it.'
                        : 'Join Chatly today.\nConnect with your friends.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.55),
                      fontSize: 14.5,
                      height: 1.6,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.1,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ==================== INPUT FIELDS ====================
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
                  _loginBtn(),

                  const SizedBox(height: 24),

                  // ==================== OR ====================
                  Row(
                    children: [
                      Expanded(
                          child: Container(
                              height: 1,
                              color: Colors.black.withOpacity(0.07))),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          'OR',
                          style: TextStyle(
                            color: Color(0xFF8F92A1),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.5,
                          ),
                        ),
                      ),
                      Expanded(
                          child: Container(
                              height: 1,
                              color: Colors.black.withOpacity(0.07))),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // ==================== SIGN UP TOGGLE ====================
                  GestureDetector(
                    onTap: () => setState(() {
                      _isLogin = !_isLogin;
                      _error = null;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
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


                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4A90E2).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.lock_outline, color: Color(0xFF4A90E2), size: 16),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          'Your data is safe and encrypted. Only your\napproved contacts can message you.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black.withOpacity(0.5), fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

        ],
      ),
    );
  }

  // ==================== 3D LOGO ====================
  Widget _logo3D() {
    return AnimatedBuilder(
      animation: _floatCtrl,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, math.sin(_floatCtrl.value * math.pi * 2) * 3),
        child: Container(
          width: 130,
          height: 130,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0B1F3A),
                Color(0xFF1E2A5F),
                Color(0xFF3D1E7C),
              ],
              stops: [0.0, 0.5, 1.0],
            ),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              // Deep shadow below
              BoxShadow(
                color: const Color(0xFF3D1E7C).withOpacity(0.5),
                blurRadius: 40,
                offset: const Offset(0, 20),
                spreadRadius: -5,
              ),
              // Soft outer glow
              BoxShadow(
                color: const Color(0xFF4A90E2).withOpacity(0.35),
                blurRadius: 60,
                offset: const Offset(0, 8),
                spreadRadius: 4,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Inner bubble (white with 3D shadow)
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white, Color(0xFFEEF1FF)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: Colors.white.withOpacity(0.9),
                      blurRadius: 4,
                      offset: const Offset(-2, -2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _dot(const Color(0xFF4A90E2), 9),
                    const SizedBox(width: 5),
                    _dot(const Color(0xFF5B7BE2), 9),
                    const SizedBox(width: 5),
                    _dot(const Color(0xFF7C4DFF), 9),
                  ],
                ),
              ),
              // Small dot overlay top-left
              Positioned(
                top: 22,
                left: 22,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== 3D FLOATING BUBBLE ====================
  Widget _bubble3D({
    required double size,
    required List<Color> colors,
    required Color dotColor,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // Shadow behind
          Positioned(
            top: 8,
            left: 0,
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
                    color: colors.first.withOpacity(0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
            ),
          ),
          // Main bubble (front)
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color.lerp(colors[0], Colors.white, 0.3)!,
                    colors[0],
                    colors[1],
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: const [0.0, 0.5, 1.0],
                ),
                borderRadius: BorderRadius.circular(size * 0.35),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _dot(dotColor, size * 0.13),
                    SizedBox(width: size * 0.07),
                    _dot(dotColor, size * 0.13),
                    SizedBox(width: size * 0.07),
                    _dot(dotColor, size * 0.13),
                  ],
                ),
              ),
            ),
          ),
          // Highlight top-left
          Positioned(
            top: 4,
            left: 6,
            child: Container(
              width: size * 0.25,
              height: size * 0.15,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.4),
                borderRadius: BorderRadius.circular(size * 0.15),
              ),
            ),
          ),
        ],
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
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF8F92A1),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 2),
                  TextField(
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
                      hintStyle: TextStyle(
                        color: const Color(0xFF0B1F3A).withOpacity(0.4),
                        fontSize: 15.5,
                        fontWeight: FontWeight.w500,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
            if (suffix != null) suffix,
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }

  // ==================== LOGIN BUTTON ====================
  Widget _loginBtn() {
    return Container(
      height: 60,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2196F3), Color(0xFF7C4DFF)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A90E2).withOpacity(0.45),
            blurRadius: 25,
            offset: const Offset(0, 12),
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
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.arrow_forward,
                          color: Colors.white, size: 22),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ==================== HELPERS ====================
  Widget _orb(double size, Color color, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withOpacity(opacity), color.withOpacity(0)],
          ),
        ),
      );

  Widget _sparkle(double size, double opacity) => Icon(
        Icons.star_rounded,
        color: const Color(0xFF9C8FFF).withOpacity(opacity),
        size: size,
      );

  Widget _dot(Color c, [double s = 8]) => Container(
        width: s,
        height: s,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      );

  Widget _tagText(String t) => Text(
        t,
        style: const TextStyle(
          fontSize: 15.5,
          color: Color(0xFF5A6B8A),
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
        ),
      );

  Widget _tagDot() => Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        width: 4,
        height: 4,
        decoration: const BoxDecoration(
          color: Color(0xFF5A6B8A),
          shape: BoxShape.circle,
        ),
      );
}

// ==================== WAVE PAINTER ====================
class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Back wave (soft purple)
    final paint1 = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF9C8FFF), Color(0xFF7C4DFF)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path1 = Path();
    path1.moveTo(0, size.height * 0.55);
    path1.quadraticBezierTo(
        size.width * 0.3, size.height * 0.25, size.width * 0.6, size.height * 0.45);
    path1.quadraticBezierTo(
        size.width * 0.85, size.height * 0.62, size.width, size.height * 0.42);
    path1.lineTo(size.width, size.height);
    path1.lineTo(0, size.height);
    path1.close();
    canvas.drawPath(path1, paint1);

    // Front wave (blue gradient)
    final paint2 = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF4A90E2), Color(0xFF6BB8FF)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path2 = Path();
    path2.moveTo(0, size.height * 0.7);
    path2.quadraticBezierTo(
        size.width * 0.35, size.height * 0.5, size.width * 0.7, size.height * 0.68);
    path2.quadraticBezierTo(
        size.width * 0.9, size.height * 0.78, size.width, size.height * 0.6);
    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
