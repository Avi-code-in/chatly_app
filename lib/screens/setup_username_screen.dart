import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../theme.dart';
import 'chat_list_screen.dart';

class SetupUsernameScreen extends StatefulWidget {
  const SetupUsernameScreen({super.key});

  @override
  State<SetupUsernameScreen> createState() => _SetupUsernameScreenState();
}

class _SetupUsernameScreenState extends State<SetupUsernameScreen> {
  final _controller = TextEditingController();
  final _service = ChatService();
  bool _checking = false;
  bool _available = false;
  String? _error;

  Future<void> _check() async {
    final username = _controller.text.trim().toLowerCase();
    if (username.length < 3) {
      setState(() => _error = 'At least 3 characters');
      return;
    }
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(username)) {
      setState(() => _error = 'Only a-z, 0-9, _ allowed');
      return;
    }
    setState(() {
      _checking = true;
      _error = null;
    });
    final available = await _service.isUsernameAvailable(username);
    setState(() {
      _checking = false;
      _available = available;
      if (!available) _error = 'Username already taken';
    });
  }

  Future<void> _save() async {
    if (!_available) return;
    await _service.setUsername(_controller.text.trim());
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
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose your username',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This is how others will find you on Chatly. Choose wisely.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF8F92A1),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _available
                      ? Colors.green
                      : _error != null
                          ? Colors.red.withOpacity(0.5)
                          : const Color(0xFF2196F3).withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '@',
                      style: TextStyle(
                        color: Color(0xFF2196F3),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onChanged: (_) {
                        setState(() {
                          _available = false;
                          _error = null;
                        });
                      },
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'yourname',
                        hintStyle: TextStyle(
                          color: Color(0xFF8F92A1),
                          fontWeight: FontWeight.normal,
                        ),
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 18),
                      ),
                    ),
                  ),
                  if (_available)
                    const Padding(
                      padding: EdgeInsets.only(right: 16),
                      child: Icon(Icons.check_circle,
                          color: Colors.green, size: 24),
                    ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: Colors.red, size: 16),
                  const SizedBox(width: 6),
                  Text(_error!,
                      style: const TextStyle(
                          color: Colors.red, fontSize: 13)),
                ],
              ),
            ],
            if (_available) ...[
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  SizedBox(width: 6),
                  Text('Username available!',
                      style: TextStyle(
                          color: Colors.green, fontSize: 13)),
                ],
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _checking
                    ? null
                    : _available
                        ? _save
                        : _check,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: _checking
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text(
                        _available ? 'Save & Continue' : 'Check Availability',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
