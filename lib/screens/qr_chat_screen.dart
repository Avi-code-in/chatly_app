import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/chat_service.dart';
import '../theme.dart';
import 'chat_screen.dart';

class QRChatScreen extends StatefulWidget {
  final String chatId;
  final String userName;
  const QRChatScreen({
    super.key,
    required this.chatId,
    required this.userName,
  });

  @override
  State<QRChatScreen> createState() => _QRChatScreenState();
}

class _QRChatScreenState extends State<QRChatScreen> {
  final _service = ChatService();

  @override
  Widget build(BuildContext context) {
    final qrData = 'chatly://chat/${widget.chatId}';

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text('Share QR Code'),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppTheme.softBlueGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: AppTheme.softShadow,
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 240,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: AppColors.primary,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 30),
            Text(
              widget.userName,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Scan this QR code to start chatting',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 40),
            TextButton.icon(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      chatId: widget.chatId,
                      otherUserName: widget.userName,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.chat, color: AppColors.primary),
              label: const Text(
                'Open Chat',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
