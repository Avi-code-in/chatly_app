import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../theme.dart';

class ChatLockScreen extends StatefulWidget {
  final VoidCallback onUnlock;
  const ChatLockScreen({super.key, required this.onUnlock});

  @override
  State<ChatLockScreen> createState() => _ChatLockScreenState();
}

class _ChatLockScreenState extends State<ChatLockScreen> {
  final _auth = LocalAuthentication();
  bool _trying = false;

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  Future<void> _authenticate() async {
    setState(() => _trying = true);
    try {
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) {
        widget.onUnlock();
        return;
      }
      final ok = await _auth.authenticate(
        localizedReason: 'Unlock chat',
      );
      if (ok) widget.onUnlock();
    } catch (e) {
      print('Auth error: $e');
    }
    if (mounted) setState(() => _trying = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                gradient: AppTheme.blueGradient,
                shape: BoxShape.circle,
                boxShadow: AppTheme.blueShadow,
              ),
              child: const Icon(Icons.lock, color: Colors.white, size: 60),
            ),
            const SizedBox(height: 30),
            const Text('Chat is locked',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text('Unlock with fingerprint or PIN',
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 30),
            if (_trying)
              const CircularProgressIndicator(color: AppColors.primary)
            else
              ElevatedButton.icon(
                onPressed: _authenticate,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Unlock'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
