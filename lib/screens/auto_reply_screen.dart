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
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _service.getAutoReply().first;
    if (data != null && mounted) {
      setState(() {
        _messageController.text = data['message'] ?? '';
        _enabled = data['enabled'] ?? false;
        _onlyOutsideHours = data['onlyOutsideHours'] ?? false;
        _startHour = data['startHour'] ?? 22;
        _endHour = data['endHour'] ?? 9;
        _loaded = true;
      });
    } else {
      _loaded = true;
    }
  }

  Future<void> _save() async {
    await _service.saveAutoReply(
      message: _messageController.text.trim(),
      enabled: _enabled,
      onlyOutsideHours: _onlyOutsideHours,
      startHour: _startHour,
      endHour: _endHour,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Auto-reply saved!'),
            backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text('Auto-Reply'),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: !_loaded
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: AppTheme.softBlueGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.smart_toy,
                            color: AppColors.primary, size: 28),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Auto-reply sends an automatic response when someone messages you.',
                            style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                                height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable Auto-Reply',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    value: _enabled,
                    activeColor: AppColors.primary,
                    onChanged: (v) => setState(() => _enabled = v),
                  ),
                  const SizedBox(height: 12),
                  const Text('Reply message',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TextField(
                      controller: _messageController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText:
                            'e.g. Hi! I am busy right now. Will reply soon.',
                        hintStyle: TextStyle(
                            color: AppColors.textSecondary, fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Only outside business hours',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      'From ${_startHour}:00 to ${_endHour}:00',
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: _onlyOutsideHours,
                    activeColor: AppColors.primary,
                    onChanged: (v) => setState(() => _onlyOutsideHours = v),
                  ),
                  if (_onlyOutsideHours) ...[
                    const SizedBox(height: 8),
                    const Text('Start hour (24h)',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    Slider(
                      value: _startHour.toDouble(),
                      min: 0,
                      max: 23,
                      divisions: 23,
                      label: '$_startHour:00',
                      activeColor: AppColors.primary,
                      onChanged: (v) =>
                          setState(() => _startHour = v.round()),
                    ),
                    const Text('End hour (24h)',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    Slider(
                      value: _endHour.toDouble(),
                      min: 0,
                      max: 23,
                      divisions: 23,
                      label: '$_endHour:00',
                      activeColor: AppColors.primary,
                      onChanged: (v) => setState(() => _endHour = v.round()),
                    ),
                  ],
                  const SizedBox(height: 30),
                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: AppTheme.blueGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppTheme.blueShadow,
                    ),
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                      ),
                      child: const Text('Save Auto-Reply',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
