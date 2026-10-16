import 'package:flutter/material.dart';
import '../services/chat_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _service = ChatService();
  bool _backingUp = false;
  bool _restoring = false;
  String _progress = '';

  Future<void> _backup() async {
    setState(() {
      _backingUp = true;
      _progress = 'Preparing backup...';
    });

    try {
      final backup = await _service.exportBackup();
      final stats = backup['stats'] as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _progress =
              'Backed up ${stats['totalChats']} chats, ${stats['totalMessages']} messages';
        });
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Backup complete!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _backingUp = false;
          _progress = '';
        });
      }
    }
  }

  Future<void> _restore() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Restore backup?'),
        content: const Text(
            'This will restore all chats and messages from your last backup. Existing data will not be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5B4DFF),
              foregroundColor: Colors.white,
            ),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _restoring = true;
      _progress = 'Restoring messages...';
    });

    try {
      final count = await _service.restoreBackup();
      if (mounted) {
        setState(() {
          _progress = 'Restored $count messages';
        });
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Restored $count messages!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _restoring = false;
          _progress = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FF),
      appBar: AppBar(
        title: const Text('Backup & Restore'),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: _service.getBackupInfo(),
        builder: (ctx, snap) {
          final info = snap.data;
          final lastBackup = info?['lastBackup'] as String?;
          final totalChats = info?['totalChats'] ?? 0;
          final totalMessages = info?['totalMessages'] ?? 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF5B4DFF), Color(0xFF7C4DFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF5B4DFF).withOpacity(0.3),
                        blurRadius: 25,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.cloud_done,
                          color: Colors.white, size: 60),
                      const SizedBox(height: 16),
                      const Text(
                        'Cloud Backup',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        lastBackup != null
                            ? 'Last backup: ${_fmtDate(lastBackup)}'
                            : 'No backup yet',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _statRow(Icons.chat_bubble_outline, 'Total Chats',
                          '$totalChats'),
                      const Divider(height: 24),
                      _statRow(Icons.message_outlined, 'Total Messages',
                          '$totalMessages'),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                _actionBtn(
                  icon: Icons.cloud_upload_outlined,
                  label: _backingUp ? 'Backing up...' : 'Backup Now',
                  loading: _backingUp,
                  onTap: _backup,
                ),

                const SizedBox(height: 12),

                _actionBtn(
                  icon: Icons.cloud_download_outlined,
                  label: _restoring ? 'Restoring...' : 'Restore Backup',
                  loading: _restoring,
                  onTap: _restore,
                  isOutline: true,
                ),

                if (_progress.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5B4DFF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Color(0xFF5B4DFF),
                            strokeWidth: 2,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _progress,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF5B4DFF),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                const Text(
                  'Your chats are stored securely in your account. Restore anytime on a new device after logging in with the same email.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF8F92A1),
                    fontSize: 12.5,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statRow(IconData icon, String label, String value) => Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF5B4DFF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF5B4DFF), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Color(0xFF0B1F3A),
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: Color(0xFF5B4DFF),
            ),
          ),
        ],
      );

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required bool loading,
    required VoidCallback onTap,
    bool isOutline = false,
  }) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: isOutline
              ? null
              : const LinearGradient(
                  colors: [Color(0xFF5B4DFF), Color(0xFF7C4DFF)],
                ),
          color: isOutline ? Colors.white : null,
          borderRadius: BorderRadius.circular(28),
          border: isOutline
              ? Border.all(color: const Color(0xFF5B4DFF), width: 1.5)
              : null,
          boxShadow: isOutline
              ? null
              : [
                  BoxShadow(
                    color: const Color(0xFF5B4DFF).withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      color: isOutline
                          ? const Color(0xFF5B4DFF)
                          : Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      label,
                      style: TextStyle(
                        color: isOutline
                            ? const Color(0xFF5B4DFF)
                            : Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  String _fmtDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return 'Unknown';
    }
  }
}
