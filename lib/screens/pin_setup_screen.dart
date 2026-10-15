import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../theme.dart';

class PinSetupScreen extends StatefulWidget {
  final String chatId;
  final String chatName;
  final bool isRemoving;

  const PinSetupScreen({
    super.key,
    required this.chatId,
    required this.chatName,
    this.isRemoving = false,
  });

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final _pin1 = TextEditingController();
  final _pin2 = TextEditingController();
  final _currentPin = TextEditingController();
  final _service = ChatService();
  bool _loading = false;
  String? _error;

  Future<void> _setPin() async {
    final p1 = _pin1.text.trim();
    final p2 = _pin2.text.trim();
    if (p1.length != 4) {
      setState(() => _error = 'PIN must be 4 digits');
      return;
    }
    if (p1 != p2) {
      setState(() => _error = 'PINs do not match');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    await _service.setChatPin(widget.chatId, p1);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chat locked successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  Future<void> _removePin() async {
    final current = _currentPin.text.trim();
    final stored = await _service.getChatPin(widget.chatId);
    if (stored != current) {
      setState(() => _error = 'Wrong current PIN');
      return;
    }
    setState(() => _loading = true);
    await _service.removeChatPin(widget.chatId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lock removed'),
          backgroundColor: Colors.orange,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: Text(widget.isRemoving ? 'Remove Lock' : 'Lock Chat'),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEEF1FF), Color(0xFFE0E6FF)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFF2196F3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.isRemoving ? Icons.lock_open : Icons.lock,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.isRemoving
                        ? 'Remove lock from ${widget.chatName}'
                        : 'Set 4-digit PIN for ${widget.chatName}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.isRemoving
                        ? 'Enter current PIN to remove lock'
                        : 'You\'ll need this PIN every time you open this chat',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF8F92A1),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            if (widget.isRemoving) ...[
              _pinField(_currentPin, 'Current PIN'),
            ] else ...[
              _pinField(_pin1, 'New PIN'),
              const SizedBox(height: 16),
              _pinField(_pin2, 'Confirm PIN'),
            ],

            if (_error != null) ...[
              const SizedBox(height: 16),
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
                      child: Text(_error!,
                          style: const TextStyle(
                              color: Colors.red, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 30),
            Container(
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: widget.isRemoving
                      ? [Colors.orange, Colors.deepOrange]
                      : [const Color(0xFF2196F3), const Color(0xFF1976D2)],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: (widget.isRemoving
                            ? Colors.orange
                            : const Color(0xFF2196F3))
                        .withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _loading
                      ? null
                      : (widget.isRemoving ? _removePin : _setPin),
                  borderRadius: BorderRadius.circular(30),
                  child: Center(
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                        : Text(
                            widget.isRemoving ? 'Remove Lock' : 'Set Lock',
                            style: const TextStyle(
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
    );
  }

  Widget _pinField(TextEditingController controller, String hint) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF2196F3).withOpacity(0.15), width: 1.5),
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        maxLength: 4,
        obscureText: true,
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontSize: 28, letterSpacing: 16, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          hintText: '----',
          hintStyle: TextStyle(
            color: const Color(0xFF8F92A1).withOpacity(0.5),
            fontSize: 28,
            letterSpacing: 16,
          ),
          counterText: '',
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 20),
        ),
      ),
    );
  }
}
