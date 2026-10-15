import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../theme.dart';

class AutoReplyScreen extends StatefulWidget {
  const AutoReplyScreen({super.key});

  @override
  State<AutoReplyScreen> createState() => _AutoReplyScreenState();
}

class _AutoReplyScreenState extends State<AutoReplyScreen> {
  final _service = ChatService();
  final _messageController = TextEditingController();
  bool _enabled = false;
  bool _onlyOutsideHours = false;
  int _startHour = 22;
  int _endHour = 9;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadOnce();
  }

  Future<void> _loadOnce() async {
    try {
      final data = await _service.getAutoReply().first
          .timeout(const Duration(seconds: 5));
      if (data != null && mounted) {
        setState(() {
          _messageController.text = data['message'] ?? '';
          _enabled = data['enabled'] ?? false;
          _onlyOutsideHours = data['onlyOutsideHours'] ?? false;
          _startHour = data['startHour'] ?? 22;
          _endHour = data['endHour'] ?? 9;
        });
      }
    } catch (e) {
      print('Auto-reply load error: $e');
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _service.saveAutoReply(
        message: _messageController.text.trim(),
        enabled: _enabled,
        onlyOutsideHours: _onlyOutsideHours,
        startHour: _startHour,
        endHour: _endHour,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Auto-reply saved!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text('Auto-Reply'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFEEF1FF), Color(0xFFE0E6FF)]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.smart_toy, color: Color(0xFF2196F3), size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Auto-reply sends an automatic response when someone messages you.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF1A1A2E), height: 1.4)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable Auto-Reply', style: TextStyle(fontWeight: FontWeight.w600)),
              value: _enabled,
              activeColor: const Color(0xFF2196F3),
              onChanged: (v) => setState(() => _enabled = v),
            ),
            const SizedBox(height: 12),
            const Text('Reply message', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF2196F3).withOpacity(0.15), width: 1.5)),
              child: TextField(
                controller: _messageController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'e.g. Hi! I am busy right now. Will reply soon.',
                  hintStyle: TextStyle(color: Color(0xFF8F92A1), fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Only outside business hours', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('From ${_startHour}:00 to ${_endHour}:00'),
              value: _onlyOutsideHours,
              activeColor: const Color(0xFF2196F3),
              onChanged: (v) => setState(() => _onlyOutsideHours = v),
            ),
            if (_onlyOutsideHours) ...[
              const SizedBox(height: 8),
              Text('Start hour: $_startHour:00', style: const TextStyle(fontWeight: FontWeight.w600)),
              Slider(value: _startHour.toDouble(), min: 0, max: 23, divisions: 23, label: '$_startHour', activeColor: const Color(0xFF2196F3), onChanged: (v) => setState(() => _startHour = v.round())),
              Text('End hour: $_endHour:00', style: const TextStyle(fontWeight: FontWeight.w600)),
              Slider(value: _endHour.toDouble(), min: 0, max: 23, divisions: 23, label: '$_endHour', activeColor: const Color(0xFF2196F3), onChanged: (v) => setState(() => _endHour = v.round())),
            ],
            const SizedBox(height: 30),
            Container(
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF2196F3), Color(0xFF1976D2)]),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _saving ? null : _save,
                  borderRadius: BorderRadius.circular(30),
                  child: Center(
                    child: _saving
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Text('Save Auto-Reply', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
