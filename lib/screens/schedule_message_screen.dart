import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/chat_service.dart';
import '../theme.dart';

class ScheduleMessageScreen extends StatefulWidget {
  final String chatId;
  const ScheduleMessageScreen({super.key, required this.chatId});

  @override
  State<ScheduleMessageScreen> createState() => _ScheduleMessageScreenState();
}

class _ScheduleMessageScreenState extends State<ScheduleMessageScreen> {
  final _controller = TextEditingController();
  final _service = ChatService();
  DateTime _selectedDate = DateTime.now().add(const Duration(hours: 1));
  TimeOfDay _selectedTime =
      TimeOfDay.fromDateTime(DateTime.now().add(const Duration(hours: 1)));
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (time == null) return;
    setState(() {
      _selectedDate = date;
      _selectedTime = time;
    });
  }

  Future<void> _schedule() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please type a message')),
      );
      return;
    }
    final dt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    if (dt.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please pick a future time'),
            backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _saving = true);
    await _service.scheduleMessage(widget.chatId, text, dt);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Scheduled for ${_formatDate(dt)} at ${_formatTime(dt)}'),
          backgroundColor: Colors.green,
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
        title: const Text('Schedule Message'),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Message',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
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
                maxLines: 5,
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Type your message...',
                  hintStyle:
                      TextStyle(color: Color(0xFF8F92A1), fontSize: 15),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(18),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Send at',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDateTime,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: const Color(0xFF2196F3).withOpacity(0.15),
                      width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.schedule,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatDate(_selectedDate),
                            style: const TextStyle(
                              color: Color(0xFF1A1A2E),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _selectedTime.format(context),
                            style: const TextStyle(
                              color: Color(0xFF8F92A1),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.edit,
                        size: 18, color: Color(0xFF2196F3)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Pending scheduled messages
            const Text('Pending scheduled',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('scheduled_messages')
                  .where('senderId', isEqualTo: _service.currentUserId)
                  .where('chatId', isEqualTo: widget.chatId)
                  .where('isSent', isEqualTo: false)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData || snap.data!.docs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'No scheduled messages',
                      style:
                          TextStyle(color: Color(0xFF8F92A1), fontSize: 13),
                    ),
                  );
                }
                return Column(
                  children: snap.data!.docs.map((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    final scheduledAt =
                        DateTime.tryParse(d['scheduledAt'] ?? '') ??
                            DateTime.now();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d['text'] ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_formatDate(scheduledAt)} • ${_formatTime(scheduledAt)}',
                                  style: const TextStyle(
                                    color: Color(0xFF8F92A1),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red, size: 20),
                            onPressed: () =>
                                doc.reference.delete(),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 30),
            Container(
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
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
                  onTap: _saving ? null : _schedule,
                  borderRadius: BorderRadius.circular(30),
                  child: Center(
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text(
                            'Schedule',
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
    );
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
