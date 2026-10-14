import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../theme.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _service = ChatService();
  bool _backingUp = false;

  Future<void> _startBackup() async {
    setState(() => _backingUp = true);
    await _service.saveBackupMetadata();
    if (mounted) {
      setState(() => _backingUp = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Backup complete!'),
            backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text('Chat Backup'),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: _service.getBackupInfo(),
        builder: (context, snapshot) {
          final info = snapshot.data;
          final lastBackup = info?['lastBackup'] as String?;
          final totalChats = info?['totalChats'] ?? 0;
          final totalMessages = info?['totalMessages'] ?? 0;

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: AppTheme.blueGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: AppTheme.blueShadow,
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.cloud_upload,
                          color: Colors.white, size: 60),
                      const SizedBox(height: 16),
                      const Text('Cloud Backup',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        lastBackup != null
                            ? 'Last backup: ${_formatDate(lastBackup)}'
                            : 'No backup yet',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _infoRow(Icons.chat_bubble, 'Total Chats',
                          '$totalChats'),
                      const Divider(),
                      _infoRow(Icons.message, 'Total Messages',
                          '$totalMessages'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: AppTheme.blueGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppTheme.blueShadow,
                  ),
                  child: ElevatedButton(
                    onPressed: _backingUp ? null : _startBackup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                    ),
                    child: _backingUp
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                        : const Text('Backup Now',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Note: Messages and media are stored on Cloudinary and Firestore. This backup saves metadata and contact info.',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.4),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
          Text(value,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15)),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return 'Unknown';
    }
  }
}
