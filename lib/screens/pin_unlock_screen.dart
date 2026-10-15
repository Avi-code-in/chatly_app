import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../theme.dart';

class PinUnlockScreen extends StatefulWidget {
  final String chatId;
  final String chatName;
  final VoidCallback onUnlock;

  const PinUnlockScreen({
    super.key,
    required this.chatId,
    required this.chatName,
    required this.onUnlock,
  });

  @override
  State<PinUnlockScreen> createState() => _PinUnlockScreenState();
}

class _PinUnlockScreenState extends State<PinUnlockScreen> {
  final _controller = TextEditingController();
  final _service = ChatService();
  String? _error;
  bool _loading = false;

  Future<void> _unlock() async {
    final entered = _controller.text.trim();
    if (entered.length != 4) {
      setState(() => _error = 'Enter 4-digit PIN');
      return;
    }
    setState(() => _loading = true);
    final stored = await _service.getChatPin(widget.chatId);
    if (stored == entered) {
      widget.onUnlock();
    } else {
      setState(() {
        _error = 'Wrong PIN';
        _loading = false;
        _controller.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2196F3).withOpacity(0.4),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.lock, color: Colors.white, size: 50),
                ),
                const SizedBox(height: 30),
                Text(
                  widget.chatName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This chat is locked',
                  style: TextStyle(color: Color(0xFF8F92A1), fontSize: 14),
                ),
                const SizedBox(height: 30),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: const Color(0xFF2196F3).withOpacity(0.15),
                        width: 1.5),
                  ),
                  child: TextField(
                    controller: _controller,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: true,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 28,
                        letterSpacing: 16,
                        fontWeight: FontWeight.bold),
                    onSubmitted: (_) => _unlock(),
                    decoration: const InputDecoration(
                      hintText: '----',
                      hintStyle: TextStyle(
                        color: Color(0xFF8F92A1),
                        fontSize: 28,
                        letterSpacing: 16,
                      ),
                      counterText: '',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 20),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: const TextStyle(color: Colors.red, fontSize: 13)),
                ],
                const SizedBox(height: 24),
                Container(
                  height: 54,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2196F3).withOpacity(0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _loading ? null : _unlock,
                      borderRadius: BorderRadius.circular(30),
                      child: Center(
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5))
                            : const Text(
                                'Unlock',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
